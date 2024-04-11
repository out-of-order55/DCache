module Regfile_256X1 (
    input               CLKA,
    input               RST,
    input               DINA, 
    input [6:0]         ADDRA,
    input               WEA,
    input               ENA,
    output              DOUTA          
);
    reg[255:0]      data=0;
    always @(posedge  CLKA ) begin
        if(RST)begin
            data <= 256'b0;
        end
        else if(WEA&ENA)begin
            data[ADDRA] <= DINA;
        end
    end
    assign DOUTA = (!WEA)&(ENA)?data[ADDRA]:'b0;
endmodule
