module input_ctrl (
    input  wire       clk1k,     // 1 kHz 去抖取樣
    input  wire [3:0] key_n,     // KEY[3:0]，低有效
    output reg        k_left,    // ←
    output reg        k_right,   // →
    output reg        k_down,    // ↓（這版暫時不用）
    output reg        k_rot      // 旋轉
);
    // 4-bit 同步 + 穩定判斷
    reg [3:0] sync0, sync1, stable, prev;
    always @(posedge clk1k) begin
        sync0   <= ~key_n;            // 反相成正邏輯
        sync1   <= sync0;             // 兩級同步
        stable  <= sync1;             // 1 ms 穩定值

        // 上升沿偵測：stable & ~prev
        k_left  <=  stable[3] & ~prev[3];
        k_right <=  stable[2] & ~prev[2];
        k_rot   <=  stable[1] & ~prev[1];
        k_down  <=  1'b0;             // 這版不用
        prev    <=  stable;
    end
endmodule
