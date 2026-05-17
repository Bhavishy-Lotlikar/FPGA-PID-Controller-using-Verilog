`timescale 1ns / 1ps
//==============================================================
// btn_debounce.v
//
// Debounces a single push-button using a 20-bit counter.
// At 100 MHz clock, 2^20 = ~10 ms debounce window.
//
// Outputs:
//   btn_pulse  — one-clock-cycle HIGH on stable press
//==============================================================

module btn_debounce (
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,      // raw button input (active high)
    output reg  btn_pulse    // single-cycle pulse on press
);

    // Two-stage synchronizer to prevent metastability
    reg sync0, sync1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync0 <= 1'b0;
            sync1 <= 1'b0;
        end else begin
            sync0 <= btn_in;
            sync1 <= sync0;
        end
    end

    // 20-bit debounce counter
    reg [19:0] cnt;
    reg        btn_stable;
    reg        btn_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt        <= 20'd0;
            btn_stable <= 1'b0;
            btn_prev   <= 1'b0;
            btn_pulse  <= 1'b0;
        end else begin
            btn_pulse <= 1'b0;

            if (sync1 != btn_stable) begin
                // Input changed — start counting
                cnt <= cnt + 1'b1;
                if (&cnt) begin
                    // Counter saturated — accept new state
                    btn_stable <= sync1;
                    cnt        <= 20'd0;
                    // Generate pulse on rising edge
                    if (sync1 && !btn_prev)
                        btn_pulse <= 1'b1;
                end
            end else begin
                cnt <= 20'd0;
            end

            btn_prev <= btn_stable;
        end
    end

endmodule
