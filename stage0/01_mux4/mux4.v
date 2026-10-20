module mux4(
    input[7:0] in0,in1,in2,in3,
    input[1:0] sel,
    output reg [7:0] q
);

always @(*) begin
    case(sel)
        2'b00: q = in0;
        2'b01: q = in1;
        2'b10: q = in2;
        2'b11: q = in3;
        default: q = 8'b0;
    endcase
end

endmodule