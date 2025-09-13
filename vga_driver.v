// ========================================
// 模組：vga_driver (640×480, 25 MHz pixel clock)
// 產生 VGA 時序並把 Tetris 畫到螢幕
// ========================================
`timescale 1ns/1ps

module vga_driver #(
    parameter H_VISIBLE     = 640,
    parameter H_FRONT_PORCH = 16,
    parameter H_SYNC_PULSE  = 96,
    parameter H_BACK_PORCH  = 48,
    parameter V_VISIBLE     = 480,
    parameter V_FRONT_PORCH = 10,
    parameter V_SYNC_PULSE  = 2,
    parameter V_BACK_PORCH  = 33
)(
    // ─ Clock / Reset ───────────────────────
    input  wire        pix_clk,   // 25 MHz 來自 PLL
    input  wire        iRST_N,    // active-low

    // ─ 遊戲資料 ─────────────────────────────
    input  wire [199:0] field,    // 20×10 bitmap
    input  wire [15:0]  cur_shape,// 4×4 bitmap
    input  wire  [4:0]  cur_x,
    input  wire  [4:0]  cur_y,
    input  wire  [2:0]  cur_col,
    input  wire         game_over,

    // ─ VGA 端口 ─────────────────────────────
    output reg  [9:0]   oVGA_R,
    output reg  [9:0]   oVGA_G,
    output reg  [9:0]   oVGA_B,
    output reg          oVGA_H_SYNC,
    output reg          oVGA_V_SYNC,
    output wire         oVGA_BLANK,
    output wire         oVGA_SYNC,
    output wire         oVGA_CLOCK
);
    // ─ 水平 / 垂直總像素 ────────────────────
    localparam H_TOTAL = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH; // 800
    localparam V_TOTAL = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; // 525

    // ─ 計數器 ───────────────────────────────
    reg [9:0] h_cnt, v_cnt;

    always @(posedge pix_clk or negedge iRST_N)
        if (!iRST_N) h_cnt <= 10'd0;
        else         h_cnt <= (h_cnt == H_TOTAL-1) ? 10'd0 : h_cnt + 10'd1;

    always @(posedge pix_clk or negedge iRST_N)
        if (!iRST_N) v_cnt <= 10'd0;
        else if (h_cnt == H_TOTAL-1)
                     v_cnt <= (v_cnt == V_TOTAL-1) ? 10'd0 : v_cnt + 10'd1;

    // ─ 同步訊號 (負脈波) ─────────────────────
    always @(posedge pix_clk or negedge iRST_N) begin
        if (!iRST_N) begin
            oVGA_H_SYNC <= 1'b1;
            oVGA_V_SYNC <= 1'b1;
        end else begin
            oVGA_H_SYNC <= (h_cnt < H_SYNC_PULSE) ? 1'b0 : 1'b1;
            oVGA_V_SYNC <= (v_cnt < V_SYNC_PULSE) ? 1'b0 : 1'b1;
        end
    end

    // ─ 可視區 & cell 座標 ───────────────────
    wire visible = (h_cnt >= H_SYNC_PULSE + H_BACK_PORCH) &&
                   (h_cnt <  H_SYNC_PULSE + H_BACK_PORCH + H_VISIBLE) &&
                   (v_cnt >= V_SYNC_PULSE + V_BACK_PORCH) &&
                   (v_cnt <  V_SYNC_PULSE + V_BACK_PORCH + V_VISIBLE);

    wire [4:0] cell_x = (h_cnt - (H_SYNC_PULSE + H_BACK_PORCH)) >> 5; // ÷32
    wire [4:0] cell_y = (v_cnt - (V_SYNC_PULSE + V_BACK_PORCH))  / 24; // ÷24

    // ─ 顏色決定 ─────────────────────────────
    reg cell_on; reg [2:0] cell_color;

    always @* begin
        cell_on    = 1'b0;
        cell_color = 3'd0;

        if (cell_x < 10 && cell_y < 20) begin
            if (field[cell_y*10 + cell_x]) begin
                cell_on    = 1'b1;
                cell_color = 3'd2;      // 固定磚塊：黃
            end else if (cell_x>=cur_x && cell_x<cur_x+4 &&
                         cell_y>=cur_y && cell_y<cur_y+4 &&
                         cur_shape[(cell_y-cur_y)*4 + (cell_x-cur_x)]) begin
                cell_on    = 1'b1;
                cell_color = cur_col;   // 活動方塊
            end
        end
    end

    // ─ 3bit→30bit 映射 ─────────────────────
    function [29:0] map(input [2:0] c);
        case (c)
          0: map = {10'd0,10'd0,10'd0};
          1: map = {10'd0,10'd0,10'h3FF};
          2: map = {10'h3FF,10'h3FF,10'd0};
          3: map = {10'd0,10'h3FF,10'd0};
          4: map = {10'h3FF,10'd0,10'd0};
          5: map = {10'h3FF,10'd0,10'h3FF};
          6: map = {10'd0,10'h3FF,10'h3FF};
          7: map = {10'h3FF,10'h3FF,10'h3FF};
        endcase
    endfunction

    wire [29:0] rgb = map(cell_color);

    // ─ 螢幕輸出 ─────────────────────────────
    always @(posedge pix_clk or negedge iRST_N)
        if (!iRST_N) {oVGA_R,oVGA_G,oVGA_B} <= 0;
        else if (visible && cell_on && !game_over) {oVGA_R,oVGA_G,oVGA_B} <= rgb;
        else if (visible &&  game_over)            {oVGA_R,oVGA_G,oVGA_B} <= {10'h100,10'd0,10'd0};
        else                                       {oVGA_R,oVGA_G,oVGA_B} <= 0;

    // ─ 其餘腳位 ─────────────────────────────
    assign oVGA_BLANK = 1'b1;     // 固定 High
    assign oVGA_SYNC  = 1'b0;
    assign oVGA_CLOCK = ~pix_clk; // 180° shift
endmodule
