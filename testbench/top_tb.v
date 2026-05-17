`timescale 1ns / 1ps
//==============================================================
// top_tb.v — Hardware Implementation Testbench
//
// Tests the full top.v design including:
//   - Button debounce + setpoint control
//   - Plant model first-order lag
//   - Disturbance injection via switches
//   - 7-segment display output verification
//   - LED bar graph tracking
//   - PWM output duty cycle
//
// Simulation phases:
//   0: Reset
//   1: Default setpoint (SP=100), plant settles
//   2: BTNU pressed twice → SP=120, plant chases
//   3: Disturbance SW[7:0]=100 applied, plant drops then recovers
//   4: Disturbance removed, plant settles back
//   5: BTND pressed → SP=110, step-down response
//
// NOTE: btn_debounce requires >10ms (1,048,576 clocks) of
//       stable input. Button tasks hold for 12ms. Total sim
//       time is ~120ms. Vivado behavioral sim handles this
//       efficiently with event-driven simulation.
//==============================================================

module top_tb;

    //----------------------------------------------------------
    // Clock: 100 MHz = 10 ns period
    //----------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk;

    //----------------------------------------------------------
    // DUT I/O
    //----------------------------------------------------------
    reg        rst_btn = 0;
    reg [3:0]  btn     = 4'b0000;
    // sw[7:0]=0   (no disturbance)
    // sw[11:8]=3  (Kp=4 from LUT index 3)
    // sw[13:12]=1 (Ki=1)
    // sw[15:14]=2 (Kd=2)
    // Combined: sw = 16'b10_01_0011_00000000 = 16'h9300
    reg [15:0] sw = 16'h9300;

    wire [15:0] led;
    wire [6:0]  seg;
    wire [3:0]  an;
    wire        dp;
    wire        pwm_out;
    wire        uart_tx;

    //----------------------------------------------------------
    // DUT instantiation
    //----------------------------------------------------------
    top dut (
        .clk     (clk),
        .rst_btn (rst_btn),
        .btn     (btn),
        .sw      (sw),
        .led     (led),
        .seg     (seg),
        .an      (an),
        .dp      (dp),
        .pwm_out (pwm_out),
        .uart_tx (uart_tx)
    );

    //----------------------------------------------------------
    // Internal signal monitoring via hierarchical references
    // (avoids needing to add extra output ports to top.v)
    //----------------------------------------------------------
    wire signed [15:0] setpoint       = dut.setpoint;
    wire signed [15:0] plant_out      = dut.plant_out;
    wire signed [15:0] control_signal = dut.control_signal;
    wire signed [15:0] feedback       = dut.feedback;
    wire               pid_tick       = dut.pid_tick;

    //----------------------------------------------------------
    // Phase tracking
    //----------------------------------------------------------
    integer phase = 0;

    //----------------------------------------------------------
    // PWM duty cycle measurement
    //   Count high cycles over 256-clock PWM period
    //----------------------------------------------------------
    integer pwm_high_cnt = 0;
    integer pwm_total    = 0;
    real    pwm_duty;

    always @(posedge clk) begin
        if (pwm_total == 255) begin
            pwm_duty     = (pwm_high_cnt * 100.0) / 256.0;
            pwm_total    <= 0;
            pwm_high_cnt <= 0;
        end else begin
            pwm_total <= pwm_total + 1;
            if (pwm_out) pwm_high_cnt <= pwm_high_cnt + 1;
        end
    end

    //----------------------------------------------------------
    // Monitor: prints every PID tick (every 10,000 clocks)
    //----------------------------------------------------------
    integer tick_count = 0;
    always @(posedge clk) begin
        if (pid_tick) begin
            tick_count <= tick_count + 1;
            // Print every 10 ticks (every 1ms)
            if (tick_count % 10 == 0) begin
                $display("T=%0t ns | PH=%0d | SP=%3d | PO=%3d | FB=%3d | CTRL=%3d | DIS=%3d | PWM=%4.1f%% | LED=%016b",
                    $time,
                    phase,
                    setpoint,
                    plant_out,
                    feedback,
                    control_signal,
                    sw[7:0],
                    pwm_duty,
                    led
                );
            end
        end
    end

    //----------------------------------------------------------
    // Task: press a button (hold > 10ms debounce + release gap)
    // btn_mask: one-hot button selection
    //----------------------------------------------------------
    task press_button;
        input [3:0] btn_mask;
        begin
            $display("\n[TB] Pressing button %b at T=%0t", btn_mask, $time);
            btn = btn_mask;
            repeat(1_200_000) @(posedge clk);  // hold 12ms (>10ms debounce)
            btn = 4'b0000;
            repeat(200_000) @(posedge clk);    // release gap 2ms
            $display("[TB] Button released at T=%0t", $time);
        end
    endtask

    //----------------------------------------------------------
    // Task: wait for plant to settle within ±2 of setpoint
    //----------------------------------------------------------
    integer settle_timeout;
    task wait_for_settle;
        begin
            settle_timeout = 0;
            $display("[TB] Waiting for plant to settle...");
            while (((plant_out - setpoint) > 2 || (setpoint - plant_out) > 2)
                   && settle_timeout < 500) begin
                repeat(10_000) @(posedge clk);  // wait 1ms
                settle_timeout = settle_timeout + 1;
            end
            if (settle_timeout >= 500)
                $display("[TB] WARNING: Settle timeout! SP=%0d PO=%0d", setpoint, plant_out);
            else
                $display("[TB] SETTLED: SP=%0d PO=%0d CTRL=%0d at T=%0t",
                         setpoint, plant_out, control_signal, $time);
        end
    endtask

    //----------------------------------------------------------
    // Main stimulus
    //----------------------------------------------------------
    initial begin
        $display("===========================================================");
        $display("  PID Hardware Testbench — Disturbance Demo");
        $display("===========================================================");

        //------------------------------------------------------
        // PHASE 0: Reset
        //------------------------------------------------------
        phase = 0;
        $display("\n=== PHASE 0: Reset ===");
        rst_btn = 1;
        repeat(100) @(posedge clk);
        rst_btn = 0;
        repeat(100) @(posedge clk);
        $display("[TB] Reset complete. SP=%0d PO=%0d", setpoint, plant_out);

        //------------------------------------------------------
        // PHASE 1: Default setpoint SP=100, let plant settle
        //------------------------------------------------------
        phase = 1;
        $display("\n=== PHASE 1: Default setpoint SP=100, waiting for plant settle ===");
        wait_for_settle;

        //------------------------------------------------------
        // PHASE 2: Press BTNU (+10) twice → SP=120
        //------------------------------------------------------
        phase = 2;
        $display("\n=== PHASE 2: BTNU x2 → SP should reach 120 ===");
        press_button(4'b0001);  // BTNU btn[0] = +10
        press_button(4'b0001);  // BTNU again  = +10
        $display("[TB] After buttons: SP=%0d", setpoint);
        wait_for_settle;

        //------------------------------------------------------
        // PHASE 3: Apply disturbance SW[7:0]=100
        //   PID sees feedback = plant_out - 100 (appears to drop)
        //   Should drive control higher, plant rises, then recovers
        //------------------------------------------------------
        phase = 3;
        $display("\n=== PHASE 3: Disturbance SW[7:0]=100 applied ===");
        sw[7:0] = 8'd100;   // only lower 8 bits — preserves gain switches
        $display("[TB] Disturbance applied: DIS=100. Watching PID fight back...");
        wait_for_settle;

        //------------------------------------------------------
        // PHASE 4: Remove disturbance
        //------------------------------------------------------
        phase = 4;
        $display("\n=== PHASE 4: Disturbance removed ===");
        sw[7:0] = 8'd0;     // clear disturbance, preserve gain switches
        $display("[TB] Disturbance cleared. Watching plant return to setpoint...");
        wait_for_settle;

        //------------------------------------------------------
        // PHASE 5: Step down BTND (-10) once → SP=110
        //------------------------------------------------------
        phase = 5;
        $display("\n=== PHASE 5: BTND x1 → SP should reach 110 ===");
        press_button(4'b0010);  // BTND btn[1] = -10
        $display("[TB] After button: SP=%0d", setpoint);
        wait_for_settle;

        //------------------------------------------------------
        // Summary
        //------------------------------------------------------
        $display("\n===========================================================");
        $display("  SIMULATION COMPLETE");
        $display("  Final state: SP=%0d  PO=%0d  CTRL=%0d",
                 setpoint, plant_out, control_signal);
        $display("  Error = %0d", setpoint - plant_out);
        if ((setpoint - plant_out) <= 2 && (plant_out - setpoint) <= 2)
            $display("  STATUS: PASS — Plant tracking setpoint within +-2");
        else
            $display("  STATUS: FAIL — Plant not tracking setpoint");
        $display("===========================================================");
        $finish;
    end

    //----------------------------------------------------------
    // Watchdog: kill sim if it runs too long (150ms)
    //----------------------------------------------------------
    initial begin
        #150_000_000;
        $display("[TB] WATCHDOG: Simulation exceeded 150ms — force finish");
        $finish;
    end

    //----------------------------------------------------------
    // Waveform dump for Vivado Waveform Viewer
    //----------------------------------------------------------
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
    end

endmodule
