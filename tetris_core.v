`timescale 1ns/1ps

module tetris_core (
    input  wire        clk,          // 50 MHz
    input  wire        rst_n,        // active-low
    input  wire        drop_tick,    // 1 Hz 自動下落
    input  wire        k_left,
    input  wire        k_right,
    input  wire        k_down,
    input  wire        k_rot,

    output reg  [199:0] field,       // 20×10 bitmap
    output reg  [15:0]  cur_shape,   // 4×4 bitmap
    output reg  [4:0]   cur_x,       // 0-9
    output reg  [4:0]   cur_y,       // 0-19
    output reg  [2:0]   cur_col,     // 1-7
    output reg  [7:0]   score,
    output reg          game_over
);

//───────────────────────────────────────────
// 1. 形狀查表
//───────────────────────────────────────────
function [15:0] shape_lut;
    input [2:0] sid;
    input [1:0] rid;
    begin
        case (sid)
            3'd0: case (rid)
                      2'd0: shape_lut = 16'h0F00;
                      2'd1: shape_lut = 16'h2222;
                      2'd2: shape_lut = 16'h00F0;
                      default:        shape_lut = 16'h4444;
                  endcase
            3'd1: shape_lut = 16'h6600;
            3'd2: case (rid)
                      2'd0: shape_lut = 16'h0E40;
                      2'd1: shape_lut = 16'h4C40;
                      2'd2: shape_lut = 16'h4E00;
                      default:        shape_lut = 16'h4640;
                  endcase
            3'd3: case (rid)
                      2'd0: shape_lut = 16'h8E00;
                      2'd1: shape_lut = 16'h6440;
                      2'd2: shape_lut = 16'h0E20;
                      default:        shape_lut = 16'h44C0;
                  endcase
            3'd4: case (rid)
                      2'd0: shape_lut = 16'h2E00;
                      2'd1: shape_lut = 16'h4460;
                      2'd2: shape_lut = 16'h0E80;
                      default:        shape_lut = 16'hC440;
                  endcase
            3'd5: shape_lut = rid[0] ? 16'h8C40 : 16'h06C0;
            default: shape_lut = rid[0] ? 16'h4C80 : 16'h0C60;
        endcase
    end
endfunction

//───────────────────────────────────────────
// 2. 暫存器
//───────────────────────────────────────────
reg  [2:0] shape_id;
reg  [1:0] rot_id;
reg  [2:0] shape_cnt;
reg  [2:0] color_cnt;

//───────────────────────────────────────────
// 3. 判斷能否移動
//───────────────────────────────────────────
function can_move;
    input [4:0] nx, ny;
    input [1:0] nrot;
    integer ix, iy;
    reg [15:0] sh;
    begin
        can_move = 1;
        sh = shape_lut(shape_id, nrot);
        for (iy = 0; iy < 4; iy = iy + 1)
            for (ix = 0; ix < 4; ix = ix + 1)
                if (sh[iy*4+ix]) begin
                    if (nx + ix >= 10 || ny + iy >= 20)
                        can_move = 0;
                    else if (field[(ny+iy)*10+(nx+ix)])
                        can_move = 0;
                end
    end
endfunction

//───────────────────────────────────────────
// 4. 鎖塊 + 清行（同一 task）
//───────────────────────────────────────────
task lock_and_clear;
    integer ix, iy, r, w;
    reg [199:0] tmp_field, new_field;
    begin
        tmp_field = field;

        // 畫上目前的方塊（注意邊界）
        for (iy = 0; iy < 4; iy = iy + 1)
            for (ix = 0; ix < 4; ix = ix + 1)
                if (cur_shape[iy*4+ix])
                    if ((cur_y+iy) < 20 && (cur_x+ix) < 10)
                        tmp_field[(cur_y+iy)*10 + (cur_x+ix)] = 1;

        // 從下往上掃，清滿行
        new_field = 200'd0;
        w = 19;
        for (r = 19; r >= 0; r = r - 1) begin
            if (&tmp_field[r*10 +: 10]) begin
                score <= score + 1;
            end else begin
                new_field[w*10 +: 10] = tmp_field[r*10 +: 10];
                w = w - 1;
            end
        end

        field <= new_field;
    end
endtask

//───────────────────────────────────────────
// 5. 新方塊產生器
//───────────────────────────────────────────
task new_piece;
    begin
        shape_cnt <= (shape_cnt == 3'd6) ? 3'd0 : shape_cnt + 3'd1;
        color_cnt <= (color_cnt >= 3'd7 || color_cnt == 3'd0) ? 3'd1 : color_cnt + 3'd1;

        shape_id  <= shape_cnt;
        rot_id    <= 0;
        cur_shape <= shape_lut(shape_cnt, 2'd0);
        cur_x     <= 3;
        cur_y     <= 0;
        cur_col   <= color_cnt;
    end
endtask

//───────────────────────────────────────────
// 6. 主流程
//───────────────────────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        field     <= 0;
        score     <= 0;
        game_over <= 0;
        shape_cnt <= 0;
        color_cnt <= 1;
        new_piece();
    end else if (!game_over) begin
        // 左右移動
        if (k_left  && can_move(cur_x-1, cur_y, rot_id)) cur_x <= cur_x - 1;
        if (k_right && can_move(cur_x+1, cur_y, rot_id)) cur_x <= cur_x + 1;

        // 旋轉
        if (k_rot && can_move(cur_x, cur_y, rot_id + 1)) begin
            rot_id    <= rot_id + 1;
            cur_shape <= shape_lut(shape_id, rot_id + 1);
        end

        // 快速下落
        if (k_down && can_move(cur_x, cur_y+1, rot_id)) cur_y <= cur_y + 1;

        // 自動下落
        if (drop_tick) begin
            if (can_move(cur_x, cur_y+1, rot_id)) begin
                cur_y <= cur_y + 1;
            end else begin
                lock_and_clear();
                new_piece();
                if (!can_move(cur_x, cur_y, rot_id))
                    game_over <= 1;
            end
        end
    end
end

endmodule
