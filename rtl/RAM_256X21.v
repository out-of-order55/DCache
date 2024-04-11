module RAM_256X21 (
    input               CLKA,
    input               RST,
    input [20:0]        DINA, 
    input [7:0]         ADDRA,
    input               WEA,
    input               ENA,
    output [20:0]       DOUTA          
);
    integer  i;
    reg[20:0]    RAM[255:0];
    reg[20:0]    data_temp;
    always @(posedge CLKA) begin
        if(RST)begin
            for(i=0;i<256;i=i+1)begin
                RAM[i] <= 'b0;
            end
        end
        if((WEA)&ENA)begin
            RAM[ADDRA] <= DINA;
        end
    end
    always @(posedge CLKA) begin
        if(ENA&(!(WEA)))begin
            data_temp <= RAM[ADDRA];
        end
    end
    assign DOUTA = data_temp; 
endmodule
