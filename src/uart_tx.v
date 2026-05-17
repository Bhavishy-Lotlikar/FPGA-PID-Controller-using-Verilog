`timescale 1ns / 1ps
//==============================================================
// uart_tx.v
//
// Minimal 8-N-1 UART transmitter at 115200 baud (50 MHz clk).
// Baud divisor = 50_000_000 / 115200 = 434 cycles/bit.
//
// Usage:
//   - Assert tx_start HIGH for 1 cycle with tx_data valid
//   - tx_busy goes HIGH during transmission
//   - tx_done pulses HIGH for 1 cycle on completion
//
// Top-level module sends a formatted CSV string periodically.
//==============================================================

module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,   // 1-cycle pulse to begin
    input  wire [7:0] tx_data,    // byte to send
    output reg        tx,         // serial output pin
    output reg        tx_busy,    // HIGH while sending
    output reg        tx_done     // 1-cycle pulse when done
);

    localparam BAUD_DIV = 16'd434; // 50 MHz / 115200

    reg [15:0] baud_cnt;
    reg [3:0]  bit_idx;   // 0=start, 1-8=data, 9=stop
    reg [9:0]  shift_reg; // {stop, data[7:0], start}

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            baud_cnt  <= 16'd0;
            bit_idx   <= 4'd0;
            shift_reg <= 10'h3FF;
        end
        else begin
            tx_done <= 1'b0;

            if (!tx_busy) begin
                tx <= 1'b1;
                if (tx_start) begin
                    // Load: stop(1) | data[7:0] | start(0)
                    shift_reg <= {1'b1, tx_data, 1'b0};
                    tx_busy   <= 1'b1;
                    baud_cnt  <= 16'd0;
                    bit_idx   <= 4'd0;
                end
            end
            else begin
                if (baud_cnt < BAUD_DIV - 1) begin
                    baud_cnt <= baud_cnt + 16'd1;
                end
                else begin
                    baud_cnt <= 16'd0;
                    tx       <= shift_reg[0];      // LSB first
                    shift_reg <= {1'b1, shift_reg[9:1]}; // shift right

                    if (bit_idx == 4'd9) begin
                        tx_busy  <= 1'b0;
                        tx_done  <= 1'b1;
                        bit_idx  <= 4'd0;
                    end
                    else begin
                        bit_idx <= bit_idx + 4'd1;
                    end
                end
            end
        end
    end

endmodule
