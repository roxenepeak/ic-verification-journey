// 4 位加法器（DUT）
// TODO：自己实现，要求 {cout, sum} = a + b + cin
module adder4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire       cout
);
    // TODO：在这里写加法逻辑
    assign {cout,sum} = a+b+cin;

endmodule
