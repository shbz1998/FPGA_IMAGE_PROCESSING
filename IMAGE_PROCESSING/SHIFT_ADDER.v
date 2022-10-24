`timescale 1ns / 1ps

module SHIFT_ADDER#(parameter m=28, n=28)(A, B, C);
integer i = 0;
input [m-1:0] A;
input [n-1:0] B;
output [m+n-1:0]C;

reg [m+n-1:0] c_reg = 0;

reg [m+n-1:0] A1;
reg [n-1:0] B1;

always@*
begin
    c_reg=0;
    A1[m-1:0]=A;
    A1[m+n-1:m]=0;
    B1=B;
    for(i=0; i<n; i=i+1)
    begin
        if(B1[i]==1'b0)
        begin
            c_reg=c_reg+0;
        end
        else if (B1[i]==1'b1)
        begin
            c_reg=c_reg+(A1<<i);
        end
    end
end

assign C = (i>=n) ? c_reg : 0;

endmodule
