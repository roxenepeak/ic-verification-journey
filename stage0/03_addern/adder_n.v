// N 位参数化加法器（DUT）
// TODO：自己实现，要求 {cout, sum} = a + b + cin
module adder_n #(parameter N = 16) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    input  wire         cin,
    output wire [N-1:0] sum,
    output wire         cout
);
    // TODO：在这里写加法逻辑
    assign {cout,sum} = a+b+cin;

endmodule
