`timescale 1ns / 1ps
`define PERIOD 10
`define N 8

module MY_MULT_TB(

    );

reg [`N-1:0] a;
reg [`N-1:0] b;
wire [2*`N-1:0] c;
reg clk;

SHIFT_ADDER #(.m(`N), .n(`N)) S0(.A(a), .B(b), .C(c));

initial
begin
clk <= 0;
forever #(`PERIOD/2) clk = ~clk;
end

initial
begin



a = 8'b11100010;

#(`PERIOD);

b = 8'b01111011;





end

endmodule
