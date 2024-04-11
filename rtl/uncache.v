module uncache (
    input                   clk                 ,
    input                   rst                 ,

    input[19:0]             cache_tag           ,
    input[3:0]              cache_offset        ,
    input[7:0]              cache_index         ,

    input[2:0]              cache_state         ,
    input                   cache_r             ,
    input                   cache_w             ,
    input[19:0]             dirty_tag           ,
    input[7:0]              dirty_index         ,
    input                   dirty_signal        ,
    input[127:0]            dirty_data          ,

    input[31:0]             cache_wdata         ,
    input[3:0]              cache_wstrb         ,
    output[1:0]             cache_cnt           ,//apb is not approve brust
    output                  rd_req              ,
    output[2:0]             rd_type             ,
    output[31:0]            rd_addr             ,
    input                   rd_rdy              ,
    input                   ret_valid           ,
    input                   ret_last            ,
    input[31:0]             ret_data            ,

    output                  wr_req              ,
    output[2:0]             wr_type             ,
    output[31:0]            wr_addr             ,
    output[3:0]             wr_wstrb            ,
    output[127:0]           wr_data             ,
    input                   wr_rdy              ,

    output                  data_ok             ,
    output[127:0]           replace_data        
);
    wire            ar_handshake        = rd_req&rd_rdy; 
    wire[31:0]      raddr = {cache_tag,cache_index,4'b0};
    reg[1:0]        cnt;
    reg             axi_rready;
    reg             axi_arvalid;
    reg[31:0]       axi_raddr;
    reg[127:0]      rpl_data;
    wire[127:0]     w_data;
    reg             data_ok_r;
    reg     axi_wvalid;
    reg[127:0] axi_wdata;
    reg[31:0]  axi_awaddr;
    reg[2:0]    cache_state_r;
    parameter       IDLE   = 3'b000,
                    LOOKUP = 3'b001,
                    MISS   = 3'b010,
                    DIRTY_WRITE = 3'b011,
                    REPLACE= 3'b100,
                    REFILL = 3'b101; 
    always @(posedge clk) begin
        if(rst)begin
            cache_state_r <= 'b0;
        end
        else begin
            cache_state_r <= cache_state;
        end
    end
    always @(posedge clk) begin
        if(rst)begin
            axi_wvalid <= 'b0;
            axi_wdata  <= 'b0;
            axi_awaddr <= 'b0;
        end
        else if(axi_wvalid&wr_rdy)begin
            axi_wvalid <= 'b0;
            axi_wdata  <= 'b0;
            axi_awaddr <= 'b0;
        end
        else if((cache_state_r==LOOKUP)&&(cache_state==DIRTY_WRITE))begin
            axi_wvalid <= 'b1;
            axi_wdata  <= dirty_data;
            axi_awaddr <= {dirty_tag,dirty_index,4'b0000};
        end
    end

    always @(posedge clk) begin
        if(rst)begin
            axi_rready <= 'b1;
        end
        else if(ret_valid)begin
            axi_rready <= 'b0;
        end
        else if(ar_handshake)begin
            axi_rready <= 'b1;
        end
    end
    always @(posedge clk) begin
        if(rst)begin
            axi_arvalid <= 'b0;
            axi_raddr   <= 'b0;
        end
        else if(ar_handshake)begin
            axi_arvalid <= 'b0;
            axi_raddr   <= 'b0;
        end
        // else if((ret_valid)&&(cnt!='d3))begin
        //     axi_arvalid <= 'b1;
        //     axi_raddr   <= raddr+4*(cnt+1);
        // end
        else if((cache_state==MISS)&&(cache_state_r!=MISS))begin
            axi_arvalid <= 'b1;
            axi_raddr   <= raddr;
        end
    end
    always @(posedge clk) begin
        if(rst)begin
            cnt <= 'b0;
        end
        else if(cache_state!=MISS)begin
            cnt <= 'b0;
        end
        else if(ret_valid)begin
            cnt <= cnt +1;
        end
    end 
    always @(posedge clk) begin
        if(rst)begin
            rpl_data <= 'b0;
        end
        else if(ret_valid)begin
            rpl_data[31:0]   <= (cnt=='d0)?ret_data:rpl_data[31:0]  ;
            rpl_data[63:32]  <= (cnt=='d1)?ret_data:rpl_data[63:32] ;
            rpl_data[95:64]  <= (cnt=='d2)?ret_data:rpl_data[95:64] ;
            rpl_data[127:96] <= (cnt=='d3)?ret_data:rpl_data[127:96];
        end
    end
    always @(posedge clk) begin
        if(rst)begin
            data_ok_r <= 'b0;
        end
        else begin
            data_ok_r <= (cnt=='d3)&&(ret_valid);
        end
    end
    assign  w_data       =   (cache_offset[3:2]==0)?{rpl_data[127:32],cache_wdata}
                            :(cache_offset[3:2]==1)?{rpl_data[127:64],cache_wdata,rpl_data[31:0]}
                            :(cache_offset[3:2]==2)?{rpl_data[127:96],cache_wdata,rpl_data[63:0]}
                            :{cache_wdata,rpl_data[95:0]}
                            ;
    assign  wr_req       = axi_wvalid   ;
    assign  wr_type      = 3'b010       ;
    assign  wr_addr      = axi_awaddr   ;
    assign  wr_wstrb     = 4'b1111      ;
    assign  wr_data      = axi_wdata    ;

    assign  rd_req  = axi_arvalid;
    assign  rd_type = 'b100;
    assign  rd_addr = axi_raddr;

    assign  data_ok      = cache_state==REPLACE;
    assign  cache_cnt    = cnt;
    assign  replace_data = cache_w?w_data:rpl_data;





endmodule
