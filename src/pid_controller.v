`timescale 1ns / 1ps
//==============================================================
// PID Controller — Hardware Version (no plant model)
//
//  For Artix-7 FPGA (Basys3 / Nexys A7)
//
//  error = setpoint - feedback
//  P = Kp * error
//  I = Ki * integral(error)  [anti-windup clamped]
//  D = Kd * (error - prev_error)
//  control_signal = clamp((P+I+D) >> GAIN_SHIFT, 0, 255)
//  pwm_out duty cycle = control_signal / 255
//
//  NOTE: system_output port removed — feedback comes from
//        the real sensor/ADC in hardware.
//==============================================================

module pid_controller (
    input  wire        clk,          // 100 MHz system clock
    input  wire        rst_n,        // active-low synchronous reset

    input  wire signed [15:0] setpoint,      // desired value
    input  wire signed [15:0] feedback,      // measured plant output
    input  wire signed [15:0] Kp,            // proportional gain
    input  wire signed [15:0] Ki,            // integral gain
    input  wire signed [15:0] Kd,            // derivative gain
    input  wire        [31:0] clk_prescaler, // PID period = (prescaler+1) clocks

    output reg  signed [15:0] control_signal, // [0..255] PID output
    output reg                pwm_out,         // PWM output pin
    output wire               tick_out         // one-cycle pulse per PID sample
);

    // PWM resolution: 8-bit = 256 levels
    localparam PWM_BITS = 8;
    localparam PWM_MAX  = (1 << PWM_BITS) - 1;  // 255

    // Right-shift after PID sum to scale into 0..255
    // Kp=4, max_error~200 => P_max=800 >> 2 = 200 (fits in 0..255)
    localparam GAIN_SHIFT = 2;

    // Anti-windup: clamp integral accumulator
    localparam signed [31:0] INT_LIMIT = 32'sd2000;

    //----------------------------------------------------------
    // Prescaler — generates one PID tick per sample period
    //----------------------------------------------------------
    reg [31:0] tick_cnt;
    wire       tick = (tick_cnt == clk_prescaler);
    assign     tick_out = tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)     tick_cnt <= 32'd0;
        else if (tick)  tick_cnt <= 32'd0;
        else            tick_cnt <= tick_cnt + 32'd1;
    end

    //----------------------------------------------------------
    // PID state registers
    //----------------------------------------------------------
    reg signed [31:0] integral;
    reg signed [31:0] prev_error;

    //----------------------------------------------------------
    // Combinational PID math
    //----------------------------------------------------------
    wire signed [31:0] err     = {{16{setpoint[15]}}, setpoint}
                                - {{16{feedback[15]}}, feedback};

    wire signed [31:0] new_int = integral + err;

    wire signed [31:0] int_cl  = (new_int >  INT_LIMIT) ?  INT_LIMIT :
                                 (new_int < -INT_LIMIT)  ? -INT_LIMIT :
                                  new_int;

    wire signed [31:0] p_out   = Kp * err;
    wire signed [31:0] i_out   = Ki * int_cl;
    wire signed [31:0] d_out   = Kd * (err - prev_error);

    wire signed [31:0] raw_sum = (p_out + i_out + d_out) >>> GAIN_SHIFT;

    wire signed [15:0] ctrl_cl = (raw_sum > 32'sd255) ? 16'sd255 :
                                 (raw_sum < 32'sd0)   ? 16'sd0   :
                                  raw_sum[15:0];

    //----------------------------------------------------------
    // Register PID outputs on each sample tick
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integral       <= 32'sd0;
            prev_error     <= 32'sd0;
            control_signal <= 16'sd0;
        end
        else if (tick) begin
            integral       <= int_cl;
            prev_error     <= err;
            control_signal <= ctrl_cl;
        end
    end

    //----------------------------------------------------------
    // 8-bit PWM generator
    //   control_signal [0..255] -> duty [0..255]
    //   pwm_out = 1 when counter < duty
    //   PWM frequency = clk / 256
    //     @ 100 MHz -> PWM freq = ~390 kHz
    //----------------------------------------------------------
    reg [PWM_BITS-1:0] pwm_counter;
    reg [PWM_BITS-1:0] pwm_duty;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_counter <= 0;
            pwm_duty    <= 0;
            pwm_out     <= 1'b0;
        end
        else begin
            pwm_counter <= pwm_counter + 1'b1;

            // Update duty only on PID tick to avoid mid-cycle glitches
            if (tick) begin
                if      (control_signal <= 0)   pwm_duty <= 0;
                else if (control_signal >= 255) pwm_duty <= PWM_MAX[PWM_BITS-1:0];
                else                            pwm_duty <= control_signal[PWM_BITS-1:0];
            end

            pwm_out <= (pwm_counter < pwm_duty) ? 1'b1 : 1'b0;
        end
    end

endmodule
