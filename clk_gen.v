module clk_gen(
    input  wire clk50,
    input  wire rst_n,
    output reg  clk25,      // VGA pixel
    output reg  tick1k,     // 1 kHz (1 ms) 去抖
    output reg  tick1       // 1 Hz  自動落子
);
    reg [15:0] div25 = 0;
    reg [15:0] div1k = 0;
    reg [25:0] div1  = 0;
    always @(posedge clk50 or negedge rst_n) begin
        if (!rst_n) begin
            {div25, clk25, div1k, tick1k, div1, tick1} <= 0;
        end else begin
            // 25 MHz
            div25 <= div25 + 1;
            if (div25 == 1) begin clk25 <= ~clk25; div25 <= 0; end
            // 1 kHz
            div1k <= div1k + 1;
            if (div1k == 50000-1) begin tick1k <= 1; div1k <= 0; end
            else tick1k <= 0;
            // 1 Hz
            div1  <= div1 + 1;
            if (div1 == 25_000_000-1) begin tick1 <= 1; div1 <= 0; end
            else tick1 <= 0;
        end
    end
endmodule