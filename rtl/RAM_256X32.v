module RAM_256X32 (
    input               CLKA,
    input               RST,
    input [31:0]        DINA, 
    input [7:0]         ADDRA,
    input [3:0]         WEA,
    input               ENA,
    output [31:0]       DOUTA          
);
    integer  i;
    reg[31:0]    RAM[255:0];
    reg[31:0]    data_temp;
    always @(posedge CLKA) begin
        if(RST)begin
            for(  i=0;i<256;i=i+1)begin
                RAM[i] <= 'b0;
            end
        end
        if((|WEA)&ENA)begin
            RAM[ADDRA][31:24]   <= WEA[3]?DINA[31:24]:RAM[ADDRA][31:24];
            RAM[ADDRA][23:16]   <= WEA[2]?DINA[23:16]:RAM[ADDRA][23:16];
            RAM[ADDRA][15:8]    <= WEA[1]?DINA[15:8] :RAM[ADDRA][15:8] ;
            RAM[ADDRA][7:0]     <= WEA[0]?DINA[7:0]  :RAM[ADDRA][7:0]  ;
        end
    end
    always @(posedge CLKA) begin
        if(ENA&(!(|WEA)))begin
            data_temp <= RAM[ADDRA];
        end
    end
    assign DOUTA = data_temp;
endmodule
