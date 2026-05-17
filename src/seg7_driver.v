`timescale 1ns / 1ps
//==============================================================
// seg7_driver.v
//
// 4-digit multiplexed 7-segment display driver.
// Refreshes at ~1 kHz per digit (4 kHz total scan).
//
// Input:  four 4-bit BCD digits  [dig3 | dig2 | dig1 | dig0]
//         dig3 = leftmost, dig0 = rightmost
//
// Output: seg[6:0] — active-low cathodes (CA..CG)
//         an[3:0]  — active-low anodes (digit select)
//         dp       — decimal point (active low, always off)
//
// Segment mapping (standard common-anode):
//
//      aaa
//     f   b
//     f   b
//      ggg
//     e   c
//     e   c
//      ddd   .dp
//
//   seg = {g,f,e,d,c,b,a}  (index 6 downto 0)
//==============================================================

module seg7_driver (
    input  wire        clk,       // 100 MHz
    input  wire        rst_n,
    input  wire [3:0]  dig3,      // leftmost digit  (thousands)
    input  wire [3:0]  dig2,      // hundreds
    input  wire [3:0]  dig1,      // tens
    input  wire [3:0]  dig0,      // rightmost digit (ones)
    output reg  [6:0]  seg,       // cathodes, active low
    output reg  [3:0]  an,        // anodes,   active low
    output wire        dp         // decimal point, always off
);

    assign dp = 1'b1;  // decimal point off

    // Refresh counter: 100 MHz / 2^17 = ~763 Hz per digit
    reg [16:0] refresh_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) refresh_cnt <= 17'd0;
        else        refresh_cnt <= refresh_cnt + 17'd1;
    end

    // Top 2 bits select which digit to display
    wire [1:0] digit_sel = refresh_cnt[16:15];

    // Selected BCD digit
    reg [3:0] current_digit;
    always @(*) begin
        case (digit_sel)
            2'b00: begin an = 4'b1110; current_digit = dig0; end
            2'b01: begin an = 4'b1101; current_digit = dig1; end
            2'b10: begin an = 4'b1011; current_digit = dig2; end
            2'b11: begin an = 4'b0111; current_digit = dig3; end
        endcase
    end

    // BCD to 7-segment decoder (active low)
    // seg = {CG, CF, CE, CD, CC, CB, CA}
    always @(*) begin
        case (current_digit)
            4'd0: seg = 7'b1000000;  // 0
            4'd1: seg = 7'b1111001;  // 1
            4'd2: seg = 7'b0100100;  // 2
            4'd3: seg = 7'b0110000;  // 3
            4'd4: seg = 7'b0011001;  // 4
            4'd5: seg = 7'b0010010;  // 5
            4'd6: seg = 7'b0000010;  // 6
            4'd7: seg = 7'b1111000;  // 7
            4'd8: seg = 7'b0000000;  // 8
            4'd9: seg = 7'b0010000;  // 9
            4'hA: seg = 7'b0001000;  // A
            4'hB: seg = 7'b0000011;  // b
            4'hC: seg = 7'b1000110;  // C
            4'hD: seg = 7'b0100001;  // d
            4'hE: seg = 7'b0000110;  // E
            4'hF: seg = 7'b0001110;  // F
            default: seg = 7'b1111111; // blank
        endcase
    end

endmodule
