`timescale 1ns / 1ps
//==============================================================
// top.v — PID Disturbance Demo (No external sensor needed)
//
// How it works:
//   - A first-order lag PLANT MODEL runs inside the FPGA
//   - SW[7:0] inject a DISTURBANCE: subtracted from plant_out
//     before the PID sees it as feedback
//   - PID fights the disturbance and drives plant_out back
//     to the setpoint — visible on the 7-segment display
//
// 7-Segment display:
//   LEFT  two digits = SETPOINT  (what we want)
//   RIGHT two digits = PLANT OUT (what the plant actually is)
//   Watch right digits drop when switches flipped, then recover!
//
// Buttons:  BTNU=SP+10  BTND=SP-10  BTNR=SP+1  BTNL=SP-1
// Switches: SW[7:0]  = disturbance (0=none, 255=maximum)
//           SW[11:8] = Kp preset
//           SW[13:12]= Ki preset  (2-bit: 0,1,2,3)
//           SW[15:14]= Kd preset  (2-bit: 0,1,2,3)
// LEDs:     control_signal bar graph (fill = PID effort)
// PMOD JA1: PWM output
// UART TX:  "SP=NNN,PO=NNN,CT=NNN\r\n" @ 115200
//==============================================================

module top (
    input  wire        clk,
    input  wire        rst_btn,
    input  wire [3:0]  btn,
    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire        dp,
    output wire        pwm_out,
    output wire        uart_tx
);

    //----------------------------------------------------------
    // Reset synchronizer (active-low rst_n)
    //----------------------------------------------------------
    reg rst_sync0, rst_sync1;
    always @(posedge clk) begin
        rst_sync0 <= rst_btn;
        rst_sync1 <= rst_sync0;
    end
    wire rst_n = ~rst_sync1;

    //----------------------------------------------------------
    // Button debouncers
    // btn[0]=BTNU(+10) btn[1]=BTND(-10) btn[3]=BTNR(+1) btn[2]=BTNL(-1)
    //----------------------------------------------------------
    wire [3:0] btn_pulse;
    btn_debounce db0(.clk(clk),.rst_n(rst_n),.btn_in(btn[0]),.btn_pulse(btn_pulse[0]));
    btn_debounce db1(.clk(clk),.rst_n(rst_n),.btn_in(btn[1]),.btn_pulse(btn_pulse[1]));
    btn_debounce db2(.clk(clk),.rst_n(rst_n),.btn_in(btn[2]),.btn_pulse(btn_pulse[2]));
    btn_debounce db3(.clk(clk),.rst_n(rst_n),.btn_in(btn[3]),.btn_pulse(btn_pulse[3]));

    //----------------------------------------------------------
    // Setpoint register (range 10..245 so plant has room to move)
    //----------------------------------------------------------
    reg signed [15:0] setpoint;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) setpoint <= 16'sd100;
        else begin
            if      (btn_pulse[0] && setpoint < 16'sd235) setpoint <= setpoint + 16'sd10;
            else if (btn_pulse[1] && setpoint > 16'sd20)  setpoint <= setpoint - 16'sd10;
            else if (btn_pulse[3] && setpoint < 16'sd244) setpoint <= setpoint + 16'sd1;
            else if (btn_pulse[2] && setpoint > 16'sd11)  setpoint <= setpoint - 16'sd1;
        end
    end

    //----------------------------------------------------------
    // Gain presets
    // SW[11:8] = Kp  (4-bit LUT, same as before)
    // SW[13:12]= Ki  (2-bit: 0=0, 1=1, 2=2, 3=3)
    // SW[15:14]= Kd  (2-bit: 0=0, 1=1, 2=2, 3=4)
    //----------------------------------------------------------
    function [15:0] kp_lut;
        input [3:0] sel;
        case (sel)
            4'd0:  kp_lut = 16'd1;
            4'd1:  kp_lut = 16'd2;
            4'd2:  kp_lut = 16'd3;
            4'd3:  kp_lut = 16'd4;   // default
            4'd4:  kp_lut = 16'd5;
            4'd5:  kp_lut = 16'd6;
            4'd6:  kp_lut = 16'd8;
            4'd7:  kp_lut = 16'd10;
            4'd8:  kp_lut = 16'd12;
            4'd9:  kp_lut = 16'd14;
            4'd10: kp_lut = 16'd16;
            4'd11: kp_lut = 16'd20;
            4'd12: kp_lut = 16'd24;
            4'd13: kp_lut = 16'd28;
            4'd14: kp_lut = 16'd32;
            4'd15: kp_lut = 16'd48;
            default: kp_lut = 16'd4;
        endcase
    endfunction

    wire signed [15:0] Kp = kp_lut(sw[11:8]);
    wire signed [15:0] Ki = sw[13:12];   // 0,1,2,3 directly
    wire signed [15:0] Kd = sw[15:14];   // 0,1,2,3 directly

    // Slowed down to 10 Hz so you can visually see the system settling (50 MHz clk)
    localparam [31:0] PRESCALER = 32'd4_999_999;  // 10 Hz PID tick

    //----------------------------------------------------------
    // PID controller instance
    //----------------------------------------------------------
    wire signed [15:0] control_signal;
    wire               pwm_out_raw;
    wire               pid_tick;    // one pulse per PID sample

    wire signed [15:0] feedback;    // what PID sees = plant_out minus disturbance

    // feedback is declared here and assigned AFTER plant_out is defined below
    // See "Disturbance Injection" section for the assign statement

    pid_controller u_pid (
        .clk            (clk),
        .rst_n          (rst_n),
        .setpoint       (setpoint),
        .feedback       (feedback),
        .Kp             (Kp),
        .Ki             (Ki),
        .Kd             (Kd),
        .clk_prescaler  (PRESCALER),
        .control_signal (control_signal),
        .pwm_out        (pwm_out_raw),
        .tick_out       (pid_tick)
    );
    assign pwm_out = pwm_out_raw;

    //----------------------------------------------------------
    // Plant Model (first-order lag, runs in sync with PID tick)
    //   plant_out approaches control_signal with time constant ~8 ticks
    //   At 10 kHz: 8 ticks = 0.8 ms — fast enough to see on display
    //
    //   plant_out += (control_signal - plant_out) >> 3
    //----------------------------------------------------------
    reg signed [15:0] plant_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            plant_out <= 16'sd0;
        end
        else if (pid_tick) begin
            // First-order lag: move 1/8 toward control_signal each tick
            plant_out <= plant_out + ((control_signal - plant_out) >>> 3);
        end
    end

    //----------------------------------------------------------
    // Disturbance Injection
    //   SW[7:0] = disturbance magnitude (0 = none, 255 = maximum)
    //   Subtracted from plant_out before PID sees it as feedback.
    //   PID thinks the output is lower → increases control effort
    //   → plant_out rises above setpoint → integral corrects
    //   → plant_out settles back at setpoint despite disturbance
    //
    //   Clamped to [0..255] so feedback never goes negative.
    //----------------------------------------------------------
    wire signed [15:0] disturbed = plant_out - $signed({8'd0, sw[7:0]});
    assign feedback = (disturbed < 16'sd0)   ? 16'sd0   :
                      (disturbed > 16'sd255)  ? 16'sd255 :
                       disturbed;

    //----------------------------------------------------------
    // LED bar graph: shows PID control effort (control_signal)
    //   More LEDs lit = PID working harder to fight disturbance
    //----------------------------------------------------------
    genvar gi;
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : led_bar
            assign led[gi] = (control_signal > $signed(gi * 16)) ? 1'b1 : 1'b0;
        end
    endgenerate

    //----------------------------------------------------------
    // 7-Segment display
    //   LEFT  digits (dig3, dig2) = SETPOINT  — what we want
    //   RIGHT digits (dig1, dig0) = PLANT_OUT  — what is happening
    //   Watch right digits drop on disturbance, then recover!
    //----------------------------------------------------------
    wire [3:0] sp_h = (setpoint  / 100) % 10;
    wire [3:0] sp_l = (setpoint  / 10)  % 10;
    wire [3:0] po_h = (plant_out / 100) % 10;
    wire [3:0] po_l = (plant_out / 10)  % 10;

    seg7_driver u_seg (
        .clk  (clk),   .rst_n(rst_n),
        .dig3 (sp_h),  .dig2 (sp_l),
        .dig1 (po_h),  .dig0 (po_l),
        .seg  (seg),   .an   (an),   .dp(dp)
    );

    //----------------------------------------------------------
    // UART monitor — "SP=NNN,PO=NNN,CT=NNN\r\n" every 100 ms
    //----------------------------------------------------------
    localparam UART_PERIOD = 27'd5_000_000; // 100ms at 50 MHz

    reg [26:0] uart_timer;
    reg        uart_trigger;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin uart_timer <= 0; uart_trigger <= 0; end
        else begin
            uart_trigger <= 0;
            if (uart_timer == UART_PERIOD - 1) begin
                uart_timer <= 0; uart_trigger <= 1;
            end else uart_timer <= uart_timer + 1;
        end
    end

    reg signed [15:0] snap_sp, snap_po, snap_ct;

    wire [7:0] sp_d2 = 8'd48 + (snap_sp / 100) % 10;
    wire [7:0] sp_d1 = 8'd48 + (snap_sp /  10) % 10;
    wire [7:0] sp_d0 = 8'd48 +  snap_sp         % 10;
    wire [7:0] po_d2 = 8'd48 + (snap_po / 100) % 10;
    wire [7:0] po_d1 = 8'd48 + (snap_po /  10) % 10;
    wire [7:0] po_d0 = 8'd48 +  snap_po         % 10;
    wire [7:0] ct_d2 = 8'd48 + (snap_ct / 100) % 10;
    wire [7:0] ct_d1 = 8'd48 + (snap_ct /  10) % 10;
    wire [7:0] ct_d0 = 8'd48 +  snap_ct         % 10;

    reg [7:0]  uart_byte;
    reg        uart_start;
    wire       uart_busy, uart_done;

    uart_tx u_uart (
        .clk(clk), .rst_n(rst_n),
        .tx_start(uart_start), .tx_data(uart_byte),
        .tx(uart_tx), .tx_busy(uart_busy), .tx_done(uart_done)
    );

    // UART string: S P = d d d , P O = d d d , C T = d d d \r \n  (18 bytes)
    reg [4:0] ustate;
    localparam [4:0]
        US_IDLE=0,
        US_S=1,  US_P=2,  US_EQ1=3,  US_S2=4,  US_S1=5,  US_S0=6,  US_CM1=7,
        US_PP=8, US_OO=9, US_EQ2=10, US_P2=11, US_P1=12, US_P0=13, US_CM2=14,
        US_C=15, US_T=16, US_EQ3=17, US_C2=18, US_C1B=19,US_C0=20,
        US_CR=21,US_LF=22;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ustate <= US_IDLE; uart_start <= 0;
            snap_sp <= 0; snap_po <= 0; snap_ct <= 0;
        end else begin
            uart_start <= 0;
            case (ustate)
                US_IDLE: if (uart_trigger && !uart_busy) begin
                    snap_sp <= setpoint; snap_po <= plant_out; snap_ct <= control_signal;
                    ustate  <= US_S;
                end
                // "SP="
                US_S:    begin uart_byte<=8'h53; uart_start<=1; ustate<=US_P;   end
                US_P:    if(uart_done) begin uart_byte<=8'h50; uart_start<=1; ustate<=US_EQ1; end
                US_EQ1:  if(uart_done) begin uart_byte<=8'h3D; uart_start<=1; ustate<=US_S2;  end
                US_S2:   if(uart_done) begin uart_byte<=sp_d2; uart_start<=1; ustate<=US_S1;  end
                US_S1:   if(uart_done) begin uart_byte<=sp_d1; uart_start<=1; ustate<=US_S0;  end
                US_S0:   if(uart_done) begin uart_byte<=sp_d0; uart_start<=1; ustate<=US_CM1; end
                US_CM1:  if(uart_done) begin uart_byte<=8'h2C; uart_start<=1; ustate<=US_PP;  end
                // "PO="
                US_PP:   if(uart_done) begin uart_byte<=8'h50; uart_start<=1; ustate<=US_OO;  end
                US_OO:   if(uart_done) begin uart_byte<=8'h4F; uart_start<=1; ustate<=US_EQ2; end
                US_EQ2:  if(uart_done) begin uart_byte<=8'h3D; uart_start<=1; ustate<=US_P2;  end
                US_P2:   if(uart_done) begin uart_byte<=po_d2; uart_start<=1; ustate<=US_P1;  end
                US_P1:   if(uart_done) begin uart_byte<=po_d1; uart_start<=1; ustate<=US_P0;  end
                US_P0:   if(uart_done) begin uart_byte<=po_d0; uart_start<=1; ustate<=US_CM2; end
                US_CM2:  if(uart_done) begin uart_byte<=8'h2C; uart_start<=1; ustate<=US_C;   end
                // "CT="
                US_C:    if(uart_done) begin uart_byte<=8'h43; uart_start<=1; ustate<=US_T;   end
                US_T:    if(uart_done) begin uart_byte<=8'h54; uart_start<=1; ustate<=US_EQ3; end
                US_EQ3:  if(uart_done) begin uart_byte<=8'h3D; uart_start<=1; ustate<=US_C2;  end
                US_C2:   if(uart_done) begin uart_byte<=ct_d2; uart_start<=1; ustate<=US_C1B; end
                US_C1B:  if(uart_done) begin uart_byte<=ct_d1; uart_start<=1; ustate<=US_C0;  end
                US_C0:   if(uart_done) begin uart_byte<=ct_d0; uart_start<=1; ustate<=US_CR;  end
                US_CR:   if(uart_done) begin uart_byte<=8'h0D; uart_start<=1; ustate<=US_LF;  end
                US_LF:   if(uart_done) begin uart_byte<=8'h0A; uart_start<=1; ustate<=US_IDLE;end
                default: ustate <= US_IDLE;
            endcase
        end
    end

endmodule
