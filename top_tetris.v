//─────────────────────────────────────────────
//  top_tetris.v — kRot 同步 + SW[0] 快速下落
//─────────────────────────────────────────────
module top_tetris (
    // board I/O
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,              // KEY[0] = Reset_n
    input  wire [17:0] SW,               // SW[0] = 一直下落
    output wire [9:0]  VGA_R, VGA_G, VGA_B,
    output wire        VGA_HS, VGA_VS,
    output wire        VGA_BLANK, VGA_SYNC, VGA_CLK,
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3,
    output wire [9:0]  LEDR
);

    // ── 1. 25 MHz Pixel Clock ───────────────────
    wire pix_clk, pll_locked;
    final U_PLL (.inclk0(CLOCK_50), .c0(pix_clk), .locked(pll_locked));

    // ── 2. 1 kHz / 1 Hz Tick ────────────────────
    wire tick1k, tick1;
    clk_gen U_CLK (.clk50(CLOCK_50), .rst_n(KEY[0]),
                   .clk25(), .tick1k(tick1k), .tick1(tick1));

    // ── 3. 按鍵去抖 (1 kHz 域) ──────────────────
    wire kL, kR, kD_raw, kRot_raw;
    input_ctrl U_KEY (.clk1k(tick1k), .key_n(KEY),
                      .k_left(kL), .k_right(kR),
                      .k_down(kD_raw), .k_rot(kRot_raw));

    // ── 3A. kRot → 50 MHz 兩級同步＋脈衝抽取 ───
    reg kRot_meta, kRot_sync, kRot_prev;
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            {kRot_meta, kRot_sync, kRot_prev} <= 3'b000;
        end else begin
            kRot_meta <= kRot_raw;
            kRot_sync <= kRot_meta;
            kRot_prev <= kRot_sync;
        end
    end
    wire kRot_pulse = kRot_sync & ~kRot_prev;   // 1 個 50 MHz 週期

    // ── 3B. LEDR0 旋轉可視化 (20 ms) ───────────
    reg [19:0] rot_vis_cnt;
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0])          rot_vis_cnt <= 0;
        else if (kRot_pulse)  rot_vis_cnt <= 20'd1_000_000;
        else if (rot_vis_cnt) rot_vis_cnt <= rot_vis_cnt - 1'b1;
    end
    wire led_rot = |rot_vis_cnt;          // 1=亮

    // ── 3C. SW[0] 同步後併入 k_down ─────────────
    reg sw0_meta, sw0_sync;
    always @(posedge CLOCK_50) begin
        sw0_meta <= SW[0];
        sw0_sync <= sw0_meta;             // 兩級 FF
    end
    wire kD_fast = kD_raw | sw0_sync;     // 1=持續下落

    // ── 4. 遊戲核心 ───────────────────────────
    wire [199:0] field;
    wire [15:0]  cur_shape;
    wire [4:0]   cur_x, cur_y;
    wire [2:0]   cur_col;
    wire [7:0]   score;
    wire         game_over;

    tetris_core U_CORE (
        .clk        (CLOCK_50),
        .rst_n      (KEY[0]),
        .drop_tick  (tick1),
        .k_left     (kL),
        .k_right    (kR),
        .k_down     (kD_fast),
        .k_rot      (kRot_pulse),
        .field      (field),
        .cur_shape  (cur_shape),
        .cur_x      (cur_x),
        .cur_y      (cur_y),
        .cur_col    (cur_col),
        .score      (score),
        .game_over  (game_over)
    );

    // ── 5. VGA Driver ──────────────────────────
    vga_driver U_VGA (
        .pix_clk      (pix_clk),
        .iRST_N       (KEY[0] & pll_locked),
        .field        (field),
        .cur_shape    (cur_shape),
        .cur_x        (cur_x),
        .cur_y        (cur_y),
        .cur_col      (cur_col),
        .game_over    (game_over),
        .oVGA_R       (VGA_R),
        .oVGA_G       (VGA_G),
        .oVGA_B       (VGA_B),
        .oVGA_H_SYNC  (VGA_HS),
        .oVGA_V_SYNC  (VGA_VS),
        .oVGA_BLANK   (VGA_BLANK),
        .oVGA_SYNC    (VGA_SYNC),
        .oVGA_CLOCK   (VGA_CLK)
    );

    // ── 6. 7-Seg 顯示 ──────────────────────────
    score_display U_HEX (.score(score), .HEX0(HEX0),
                         .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3));

    // ── 7. LEDR 輸出 ───────────────────────────
    assign LEDR = {9'd0, led_rot};        // LEDR0 為旋轉脈衝，可自行關閉
endmodule
