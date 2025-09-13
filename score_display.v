module score_display(
    input  wire [7:0] score,
    output reg  [6:0] HEX0,HEX1,HEX2,HEX3
);
    function[6:0] seg(input[3:0]n);
        case(n)0:seg=7'b1000000;1:seg=7'b1111001;2:seg=7'b0100100;
                 3:seg=7'b0110000;4:seg=7'b0011001;5:seg=7'b0010010;
                 6:seg=7'b0000010;7:seg=7'b1111000;8:seg=7'b0000000;
                 9:seg=7'b0010000;default:seg=7'b1111111;endcase endfunction
    always @* begin
        HEX0 = seg(score%10);
        HEX1 = seg(score/10);
        HEX2 = 7'h7F;
        HEX3 = 7'h7F;
    end
endmodule