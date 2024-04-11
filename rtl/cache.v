module cache(
    input           clk            ,

    input           resetn         ,
    input           valid          ,
    input           op             ,
    input[7:0]      index          ,
    input[19:0]     tag            ,
    input[3:0]      offset         ,
    output          addr_ok        ,
    output          data_ok        ,
    output[31:0]    rdata          ,
    input[31:0]     wdata          ,
    input[3:0]      wstrb          ,
    output          cache_miss     ,

    output          wr_req         ,
    output[2:0]     wr_type        ,
    output[31:0]    wr_addr        ,
    output[3:0]     wr_wstrb       ,
    output[127:0]   wr_data        ,
    input           wr_rdy         ,

    output          rd_req         ,
    output[2:0]     rd_type        ,
    output[31:0]    rd_addr        ,
    input           rd_rdy         ,
    input           ret_valid      ,
    input           ret_last       ,
    input[31:0]     ret_data       
);
    wire        rst=~resetn;
    // 1T     |  2T     |
    // RDATA  | COMPARE |
    wire            read_op;
    wire            write_op;
    wire[127:0]     way0_rdata;
    wire[127:0]     way1_rdata;
    wire[127:0]     replace_data;
    wire[41:0]      rtagv;
    wire[127:0]     way0_wdata;
    wire[15:0]      way0_wstrb;
    wire[127:0]     way1_wdata;
    wire[15:0]      way1_wstrb;
    wire[127:0]     cache_way0_wdata;
    wire[15:0]      cache_way0_wstrb;
    wire[127:0]     cache_way1_wdata;
    wire[15:0]      cache_way1_wstrb;
    wire[1:0]       dirty;
    wire            lru;
    wire    cache_whit_way0;
    wire    cache_whit_way1;
    wire    cache_rhit_way0;
    wire    cache_rhit_way1;
    wire    cache_hit;
    wire[1:0]   data_offset;
//latch info
    reg[19:0]   tag_r;
    reg[3:0]    offset_r;
    reg[7:0]    index_r;
    wire[7:0]   cache_index;

    wire[19:0]  dirty_tag   ;
    wire[3:0]   dirty_offset;
    wire[7:0]   dirty_index ;
    reg         cache_dirty_signal;
    wire        cache_lru_wsignal;
    wire        lru_wdata;
    wire [20:0] tagv_wdata;
    wire[1:0]   data_wsignal;
    wire[1:0]   cache_tagv_wsiganl;
    wire[31:0]  cache_data_wstrb;
    wire        tagv_valid;
    wire        data_valid;
    wire        lru_valid;  
    wire        dirty_valid;
    wire[1:0]   cache_dirty_wsignal;
    wire        way0_dirty;
    wire        way1_dirty; 
    wire        way_sel;
    wire[127:0] dirty_data;
    wire[1:0]   cache_cnt;
    wire        cache_data_ok;
    wire        cache_write_op;    
    wire        cache_read_op ;
    wire        cache_lru     ;
    wire[1:0]   cache_dirty   ;    
    wire[3:0]   cache_wstrb   ;
    wire[19:0]  cache_tag     ;
    wire[6:0]   cache_index   ;
    wire[3:0]   cache_offset  ;
    wire[31:0]  cache_wdata   ;
    reg         lru_message;
    reg[127:0]  cache_rdata;
    reg[2:0]    main_state;

    parameter       IDLE   = 3'b000,
                    LOOKUP = 3'b001,
                    MISS   = 3'b010,
                    DIRTY_WRITE = 3'b011,
                    REPLACE= 3'b100,
                    REFILL = 3'b101; 
    always @(posedge clk) begin
        if(rst)begin
            main_state <= IDLE;
        end
        else begin
            case (main_state)
                IDLE    :begin
                    if(read_op|write_op)begin
                        main_state <= LOOKUP;
                    end
                end
                LOOKUP  :begin
                    if(cache_miss&dirty_signal)begin
                        main_state <= DIRTY_WRITE;
                    end
                    if(cache_miss&(!dirty_signal))begin
                        main_state <= MISS;
                    end
                    else if(cache_hit&(read_op|write_op))begin
                        main_state <= LOOKUP;
                    end
                    else if(cache_hezard|(!(read_op&write_op)))begin
                        main_state <= IDLE;
                    end
                end
                DIRTY_WRITE:begin
                    if(wr_req&wr_rdy)begin
                        main_state <= MISS;
                    end
                end
                MISS    :begin
                    if(ret_last)begin
                        main_state <= REPLACE;
                    end
                end
                REPLACE :begin
                    main_state <= REFILL; 
                end
                REFILL:begin
                    main_state <= IDLE; 
                end
                default: begin
                    main_state <= IDLE;
                end
            endcase
        end
    end

    assign  read_op = (!op)&valid;
    assign  write_op= (op)&valid;
    reg[72:0]   cache_info;//[31:0]->wdata [63:32]->{tag,index,offset} [67:64]->wstrb [68:69]->dirty [72:70]->{w_op,r_op,lru}
    always @(posedge clk) begin
        if(rst)begin
            cache_info <= 'b0;
        end
        else if(addr_ok)begin
            cache_info <= {
                write_op,
                read_op,
                lru,
                dirty,
                wstrb,
                tag,
                index,
                offset,
                wdata
            };
        end
    end
    assign cache_write_op = cache_info[72];
    assign cache_read_op  = cache_info[71];
    assign cache_lru      = cache_info[70];
    assign cache_dirty    = cache_info[69:68];
    assign cache_wstrb    = cache_info[67:64];
    assign cache_tag      = cache_info[63:44];
    assign cache_index    = addr_ok?index:cache_info[43:36];
    assign cache_offset   = cache_info[35:32];
    assign cache_wdata    = cache_info[31:0];
    
    assign cache_hezard = (cache_whit_way0|cache_whit_way1)&&(read_op)&&({tag,index,offset}=={rtagv[19:0],cache_index,cache_index});

    //delay 1T to update info 
    always @(posedge clk) begin
        if(rst)begin
            cache_rdata <= 'b0;
        end
        else if(main_state==REPLACE)begin
            cache_rdata <= replace_data;
        end
    end
    always @(posedge clk) begin
        if(rst)begin
            cache_dirty_signal <= 'b0;
        end
        else if(cache_data_ok)begin
            cache_dirty_signal <= 'b0;
        end
        else if(cache_miss)begin
            cache_dirty_signal <= dirty_signal;
        end
    end
    //dirty handle
    assign dirty_signal   = way_sel?way1_dirty:way0_dirty;
    assign way0_dirty     = cache_dirty[0]&way_sel&cache_miss;
    assign way1_dirty     = cache_dirty[1]&way_sel&cache_miss;
    //cache miss 
    assign way_sel      = cache_lru?'b1:'b0;
    assign dirty_tag    = way1_dirty?rtagv[40:21]
                        :way0_dirty?rtagv[19:0]
                        :'b0;
    assign dirty_index  = cache_index;
    assign dirty_data   = way1_dirty?way1_rdata
                        :way0_dirty?way0_rdata
                        :'b0;
    //
    assign cache_rhit_way0 = cache_read_op&&((rtagv[19:0] ==cache_tag)&&(rtagv[20]=='b1)) &&(main_state==LOOKUP);
    assign cache_rhit_way1 = cache_read_op&&((rtagv[40:21]==cache_tag)&&(rtagv[41]=='b1))&&(main_state==LOOKUP);
    assign cache_whit_way0 = cache_write_op&&((rtagv[19:0] ==cache_tag)&&(rtagv[20]=='b1)) &&(main_state==LOOKUP);
    assign cache_whit_way1 = cache_write_op&&((rtagv[40:21]==cache_tag)&&(rtagv[41]=='b1))&&(main_state==LOOKUP);
    assign cache_hit = cache_whit_way0|cache_rhit_way0|cache_whit_way1|cache_rhit_way1;

    assign  cache_miss = (main_state==LOOKUP)&(!cache_hit);
    assign  data_offset = cache_offset[3:2];
    assign  rdata   =    cache_rhit_way0 ? way0_rdata[32*(data_offset+1)-1-:32]
                        :cache_rhit_way1 ? way1_rdata[32*(data_offset+1)-1-:32]
                        :main_state==REFILL?cache_rdata[32*(data_offset+1)-1-:32]
                        :'b0;
    assign  addr_ok = (main_state==IDLE)||((main_state==LOOKUP)&&(cache_hit)&&(read_op|write_op)&&(!cache_hezard));
    assign  data_ok =    cache_hit?'b1:main_state==REFILL;
    //update
    assign dirty_valid = read_op|write_op|cache_data_ok;
    assign tagv_valid  = read_op|write_op|cache_data_ok;
    assign data_valid  = read_op|write_op|cache_data_ok;
    assign lru_valid   = read_op|write_op|cache_data_ok; 
    //replace signal
    assign cache_lru_wsignal = cache_rhit_way0|cache_rhit_way1|cache_data_ok;
    assign lru_wdata   = cache_rhit_way0?'b1
                        :cache_rhit_way1?'b0
                        :cache_lru?'b0
                        :'b1;

    assign cache_tagv_wsiganl = cache_data_ok?(cache_lru)?2'b10
                        :2'b01
                        :2'b0;

    assign tagv_wdata = {1'b1,cache_tag};

    assign data_wsignal =    cache_data_ok?(cache_lru)?2'b10
                                :2'b01
                                :2'b0;
    assign cache_dirty_wsignal = (cache_data_ok&cache_write_op)?(way_sel?2'b10:2'b01)
                        :(cache_data_ok&cache_read_op)?(way_sel?2'b10:2'b01)
                        :'b0;
    assign dirty_wdata  = cache_write_op?'b1:'b0;
    
//wr cache hit
    assign way0_wdata =  (cache_offset[3:2]==0)?{96'b0,cache_wdata}
                        :(cache_offset[3:2]==1)?{64'b0,cache_wdata,32'b0}
                        :(cache_offset[3:2]==2)?{32'b0,cache_wdata,64'b0}
                        :{cache_wdata,96'b0}
                        ;
    assign way0_wstrb = (cache_offset[3:2]==0)?{12'b0,cache_wstrb}
                        :(cache_offset[3:2]==1)?{8'b0,cache_wstrb,4'b0}
                        :(cache_offset[3:2]==2)?{4'b0,cache_wstrb,8'b0}
                        :{cache_wstrb,12'b0}
                        ;
    assign way1_wdata =  (cache_offset[3:2]==0)?{96'b0,cache_wdata}
                        :(cache_offset[3:2]==1)?{64'b0,cache_wdata,32'b0}
                        :(cache_offset[3:2]==2)?{32'b0,cache_wdata,64'b0}
                        :{cache_wdata,96'b0}
                        ;
    assign way1_wstrb = (cache_offset[3:2]==0)?{12'b0,cache_wstrb}
                        :(cache_offset[3:2]==1)?{8'b0,cache_wstrb,4'b0}
                        :(cache_offset[3:2]==2)?{4'b0,cache_wstrb,8'b0}
                        :{cache_wstrb,12'b0}
                        ;
    //sel if hit or miss data
    assign cache_way0_wdata =    cache_whit_way0?way0_wdata
                                :cache_data_ok?replace_data
                                :'b0;
    assign cache_way0_wstrb =    cache_whit_way0?way0_wstrb
                                :cache_data_ok&cache_write_op&(!way_sel)?way0_wstrb
                                :cache_data_ok&cache_read_op?{16{data_wsignal[0]}}
                                :'b0;
    assign cache_way1_wdata =    cache_whit_way1?way1_wdata
                                :cache_data_ok?replace_data
                                :'b0;
    assign cache_way1_wstrb =    cache_whit_way1?way1_wstrb
                                :cache_data_ok&cache_write_op&(way_sel)?way1_wstrb
                                :cache_data_ok&cache_read_op?{16{data_wsignal[1]}}
                                :'b0;
uncache uncache(
    .clk                 (clk               ),
    .rst                 (rst               ),
    .cache_tag           (cache_tag         ),
    .cache_offset        (cache_offset      ),
    .cache_index         (cache_index       ),
    .cache_state         (main_state        ),

    .dirty_tag           (dirty_tag         ),
    .dirty_index         (dirty_index       ),
    .dirty_signal        (dirty_signal      ),
    .dirty_data          (dirty_data        ),

    .cache_r             (cache_read_op     ),
    .cache_w             (cache_write_op    ),
    .cache_wdata         (cache_wdata     ),
    .cache_wstrb         (cache_wstrb     ),
    .wr_req              (wr_req            ),
    .wr_type             (wr_type           ),
    .wr_addr             (wr_addr           ),
    .wr_wstrb            (wr_wstrb          ),
    .wr_data             (wr_data           ),
    .wr_rdy              (wr_rdy            ),

    .cache_cnt           (cache_cnt         ),
    .data_ok             (cache_data_ok     ),
    .rd_req              (rd_req            ), 
    .rd_type             (rd_type           ), 
    .rd_addr             (rd_addr           ), 
    .rd_rdy              (rd_rdy            ), 
    .ret_valid           (ret_valid         ), 
    .ret_last            (ret_last          ), 
    .ret_data            (ret_data          ), 
    .replace_data        (replace_data      )
);
//replace
    genvar  i;
    generate
    for(i=0;i<4;i=i+1)
    begin:WAY0
        RAM_256X32 DATA_WAY0(
            .CLKA   (clk            ),
            .RST    (rst            ),
            .DINA   (cache_way0_wdata[32*(i+1)-1:32*i]   ), 
            .ADDRA  (cache_index    ),
            .WEA    (cache_way0_wstrb[4*(i+1)-1:4*i]     ),
            .ENA    (data_valid     ),
            .DOUTA  (way0_rdata[32*(i+1)-1:32*i] )// 1T        
        );
    end
    endgenerate
    generate
    for( i=0;i<4;i=i+1)
    begin:WAY1
        RAM_256X32 DATA_WAY1(
            .CLKA   (clk            ),
            .RST    (rst            ),
            .DINA   (cache_way1_wdata[32*(i+1)-1:32*i]   ), 
            .ADDRA  (cache_index    ),
            .WEA    (cache_way1_wstrb[4*(i+1)-1:4*i]    ),
            .ENA    (data_valid     ),
            .DOUTA  (way1_rdata[32*(i+1)-1:32*i] )//1T        
        );
    end
    endgenerate
    generate
    for( i=0;i<2;i=i+1)
    begin:TAGV
    RAM_256X21 TAGV(
        .CLKA   (clk                ),
        .RST    (rst                ),
        .DINA   (tagv_wdata         ), 
        .ADDRA  (cache_index        ),
        .WEA    (cache_tagv_wsiganl[i]    ),
        .ENA    (tagv_valid         ),
        .DOUTA  (rtagv[21*(i+1)-1:21*i] )  //1T      
    );
    end
    endgenerate

    for( i=0;i<2;i=i+1)
    begin:DIRTY
    Regfile_256X1 DIRTY(
        .CLKA   (clk),
        .RST    (rst),
        .DINA   (dirty_data ), 
        .ADDRA  (cache_index),
        .WEA    (cache_dirty_wsignal[i]),
        .ENA    (dirty_valid),
        .DOUTA  (dirty[i] )        
    );
    end
    Regfile_256X1 LRU(
        .CLKA   (clk            ),
        .RST    (rst            ),
        .DINA   (lru_wdata      ), 
        .ADDRA  (cache_index    ),
        .WEA    (cache_lru_wsignal),
        .ENA    (lru_valid      ),
        .DOUTA  (lru            ) //0T       
    );
endmodule

