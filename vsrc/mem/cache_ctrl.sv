module cache_ctrl #(
    parameter READ_WORDS    =   4,

    parameter TAG_BITS      =   14,     // TAG位宽
    parameter INDEX_BITS    =   12,     // 缓存深度，必须为2**INDEX_BITS
    parameter OFFSET_BITS   =   4,      // OFFSET位宽
    parameter WAY_NUM       =   4,      // 表示缓存共多少路

    parameter ADDR_WIDTH      = 32,        // 地址宽度
    parameter DATA_WIDTH      = 32,        // 数据宽度  
    parameter BURST_LEN_WIDTH = 8,         // 突发长度宽度
    parameter MAX_BURST_LEN   = 16,        // �?大突发长�?
    parameter ID_WIDTH        = 1,
    parameter REGION_WIDTH    = 4
)(
    input  logic                    clk,
    input  logic                    rst,

    //##---------------------------------------------##
    //主机接口
    input  logic                    re,
    input  logic [3:0]              we,
    input  logic [31:0]             addr,
    input  logic [31:0]             din,
    output logic [32*READ_WORDS-1:0]    dout,

    output logic                    done,
    output logic                    rvalid,
    output logic                    error,
    input  logic                    restart,
    output logic                    busy,

    //##---------------------------------------------##
    // 存储接口 - 数组形式，支�? WAY_NUM 个存储线�?
    // 数据存储接口
    output logic [WAY_NUM-1:0] [3:0]              data_we,
    output logic [WAY_NUM-1:0] [31:0]             data_addr,
    output logic [WAY_NUM-1:0] [31:0]             data_din,
    output logic [WAY_NUM-1:0] [31:0]             data_raddr,
    input  logic [WAY_NUM-1:0] [32*(1<<OFFSET_BITS)-1:0]  data_dout,

    // TagV存储接口
    output logic [WAY_NUM-1:0]                    tagv_we,
    output logic [WAY_NUM-1:0] [31:0]             tagv_addr_r,
    output logic [WAY_NUM-1:0] [31:0]             tagv_addr_w,
    input  logic [WAY_NUM-1:0] [TAG_BITS:0]       tagv_dout,

    // 脏位存储接口
    output logic [WAY_NUM-1:0]                    dirty_we,
    output logic [WAY_NUM-1:0] [INDEX_BITS-1:0]   dirty_waddr,
    output logic [WAY_NUM-1:0]                    dirty_din,
    output logic [WAY_NUM-1:0] [INDEX_BITS-1:0]   dirty_raddr,
    input  logic [WAY_NUM-1:0]                    dirty_dout,

    //##---------------------------------------------##
    //AXI控制接口
    output logic                            axi_start_i,          // 启动事务
    output logic                            axi_wr_rd_i,          // 0=�?, 1=�?
    output logic [DATA_WIDTH/8-1:0]         axi_wr_wstrb_i,       // wstrb e.g. 4'b1111
    output logic [ADDR_WIDTH-1:0]           axi_addr_i,           // 起始地址
    output logic [BURST_LEN_WIDTH-1:0]      axi_len_i,            // 突发长度 (实际长度 = len_i + 1)
    output logic [2:0]                      axi_size_i,           // 传输大小 (字节�? = 2^size_i)
    output logic [1:0]                      axi_burst_i,          // 突发类型
    output logic [DATA_WIDTH-1:0]           axi_data_i,           // 单数据输�?
    output logic [DATA_WIDTH-1:0]           axi_data_array_i [MAX_BURST_LEN], // 数据数组输入
    output logic                            axi_use_array_i,      // 使用数据数组模式

    input  logic                            axi_done_o,           // 事务完成
    input  logic [DATA_WIDTH-1:0]           axi_data_o,           // 读取数据
    input  logic                            axi_data_valid_o,     // 读数据有�?
    input  logic [1:0]                      axi_resp_o,           // 响应状�??
    input  logic                            axi_error_o,          // 错误指示
    input  logic                            axi_busy_o,           // 驱动忙状�?

    //##---------------------------------------------##
    //way_sel模块接口
    output logic                            cache_hit,
    output logic [$clog2(WAY_NUM)-1:0]      way_hit,
    input  logic [$clog2(WAY_NUM)-1:0]      way_sel
);

typedef enum logic [2:0] {
    IDLE        = 3'b000,
    COMPARE     = 3'b001,
    WRITE_BACK  = 3'b011,
    ALLOCATE    = 3'b100,
    REREAD      = 3'b110,
    RECOMPARE   = 3'b111,
    ERROR       = 3'b010
} cache_state_t;

cache_state_t curr_state;
cache_state_t next_state;

logic           start;
logic           hit;
logic           row_diff;

logic [31:0]    addr_ahead;
logic [31:0]    addr_buff;
logic [31:0]    addr_ahead_buff;
logic [31:0]    din_buff;
logic           re_buff;
logic           we_buff;

logic           re_buff_buff;
logic           we_buff_buff;


// 地址分解
logic [TAG_BITS-1:0]    tag;
logic [INDEX_BITS-1:0]  index;
logic [OFFSET_BITS-1:0] offset;

assign tag = addr_buff[31:31-TAG_BITS+1];
assign index = addr_buff[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];
assign offset = addr_buff[OFFSET_BITS-1:0];

// 内部信号
logic [WAY_NUM-1:0] hit_way;                    // 每路命中情况
logic [WAY_NUM-1:0] valid_way;                  // 每路有效�?
logic [WAY_NUM-1:0][TAG_BITS-1:0] tag_way;      // 每路tag�?
logic               replace_dirty;              // 替换路的脏位
logic [WAY_NUM-1:0] way_sel_onehot;             // one-hot形式的路选择


// 计算one-hot选择信号
assign way_sel_onehot = (1 << way_sel);
// 提取tagv信息
generate
    for (genvar i = 0; i < WAY_NUM; i++) begin
        assign valid_way[i] = tagv_dout[i][TAG_BITS];
        assign tag_way[i] = tagv_dout[i][TAG_BITS-1:0];
    end
endgenerate
// 命中判断
always_comb begin
    hit_way = '0;
    for (int i = 0; i < WAY_NUM; i++) begin
        hit_way[i] = valid_way[i] && (tag_way[i] == tag);
    end
    hit = |hit_way;
end
// 命中路编�?
always_comb begin
    way_hit = '0;
    for (int i = 0; i < WAY_NUM; i++) begin
        if (hit_way[i]) way_hit = i;
    end
end
assign cache_hit = hit;
// 脏位判断
assign dirty = |(dirty_dout & way_sel_onehot);
// 地址计算
always_comb begin
    start = re | (|we);
    // 注意：这里应该是addr + READ_WORDS*4 用于预取，不是减
    addr_ahead = addr + READ_WORDS * 4;
    row_diff = addr_ahead_buff[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS] != 
               addr_buff[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
end

always_comb begin
    start = re | we;
    row_diff = addr_ahead_buff[OFFSET_BITS+2] ^ addr_buff[OFFSET_BITS+2]; //不在同一行，�?要重新读
    addr_ahead = addr - READ_WORDS*4;
end

always_ff @(posedge clk or posedge rst) begin
    if(rst) begin
        addr_buff   <= 32'b0;
        addr_ahead_buff <= 32'b0;
        din_buff    <= 32'b0;
        re_buff     <= 1'b0;
        we_buff     <= 1'b0;
    end
    else if(start && ~busy) begin
        addr_buff   <= addr;
        addr_ahead_buff <= addr_ahead;
        din_buff    <= din;
        re_buff     <= re;
        we_buff     <= we;
    end
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) curr_state <= IDLE;
    else curr_state <= next_state;
end

always_comb begin
    case(curr_state)
        IDLE: begin
            if(start) begin
                next_state = COMPARE;
            end
            else begin
                next_state = IDLE;
            end
        end
        COMPARE: begin
            if(hit) begin
                if(row_diff) begin next_state = REREAD; end
                else if(start) begin next_state = COMPARE;  end
            end
            else begin
                if(dirty) begin next_state = WRITE_BACK; end
                else begin next_state = ALLOCATE; end
            end
        end
        WRITE_BACK: begin
            if(axi_error_o) begin next_state = ERROR; end
            else if(axi_done_o) begin next_state = ALLOCATE; end
            else begin next_state = WRITE_BACK; end
        end
        ALLOCATE: begin
            if(axi_error_o) begin next_state = ERROR; end
            else if(axi_done_o) begin next_state = RECOMPARE; end
            else begin next_state = ALLOCATE; end
        end
        RECOMPARE: begin
            if(hit) begin
                if(row_diff_buff) begin next_state = REREAD; end
                else if(start) begin next_state = COMPARE; end
                else begin next_state = IDLE; end
            end
            else begin
                next_state = ERROR;
            end
        end
        REREAD: begin
            if(hit) begin
                if(start) begin
                    next_state = COMPARE;
                end
                else begin
                    next_state = IDLE;
                end
            end
            else begin
                if(dirty) begin next_state = WRITE_BACK; end
                else begin next_state = ALLOCATE; end
            end
        end
        ERROR: begin
            if(restart) begin next_state = IDLE; end
            else begin next_state = ERROR; end
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end


// ============================================================================
// 组合逻辑赋�?? - 存储接口
// ============================================================================

// 数据存储接口
always_comb begin
    data_we = '0;
    data_addr = '{WAY_NUM{32'b0}};
    data_din = '{WAY_NUM{32'b0}};
    data_raddr = '{WAY_NUM{32'b0}};
    
    case(curr_state)
        COMPARE: begin
            // 读取数据
            for (int i = 0; i < WAY_NUM; i++) begin
                data_raddr[i] = {tag_way[i], index, offset};
            end
            
            // 写命中时写入数据
            if (hit && (|we_buff)) begin
                data_we[way_hit] = we_buff;
                data_addr[way_hit] = {tag, index, offset};
                data_din[way_hit] = din_buff;
            end
        end
        
        ALLOCATE: begin
            // 分配时写入从AXI读取的数�?
            if (axi_data_valid_o) begin
                data_we[way_sel] = 4'b1111; // 写入整个�?
                data_addr[way_sel] = {tag, index, offset};
                data_din[way_sel] = axi_data_o;
            end
        end
        
        REREAD, RECOMPARE: begin
            // 重新读取数据
            for (int i = 0; i < WAY_NUM; i++) begin
                data_raddr[i] = {tag_way[i], index, offset};
            end
        end
    endcase
end

// TagV存储接口
always_comb begin
    tagv_we = '0;
    tagv_addr_r = '{WAY_NUM{32'b0}};
    tagv_addr_w = '{WAY_NUM{32'b0}};
    
    // 读取地址 - 总是读取当前index的tagv
    for (int i = 0; i < WAY_NUM; i++) begin
        tagv_addr_r[i] = { {TAG_BITS{1'b0}}, index, {OFFSET_BITS{1'b0}} };
    end
    
    case(curr_state)
        ALLOCATE: begin
            // 分配完成后更新tagv
            if (axi_done_o) begin
                tagv_we[way_sel] = 1'b1;
                tagv_addr_w[way_sel] = { {TAG_BITS{1'b0}}, index, {OFFSET_BITS{1'b0}} };
            end
        end
    endcase
end

// 脏位存储接口
always_comb begin
    dirty_we = '0;
    dirty_waddr = {WAY_NUM{INDEX_BITS{1'b0}}};
    dirty_din = '0;
    dirty_raddr = {WAY_NUM{INDEX_BITS{1'b0}}};
    
    // 读取当前index的脏�?
    for (int i = 0; i < WAY_NUM; i++) begin
        dirty_raddr[i] = index;
    end
    
    case(curr_state)
        COMPARE: begin
            // 写命中时设置脏位
            if (hit && (|we_buff)) begin
                dirty_we[way_hit] = 1'b1;
                dirty_waddr[way_hit] = index;
                dirty_din[way_hit] = 1'b1;
            end
        end
        
        ALLOCATE: begin
            // 分配时清除脏位（因为是干�?数据�?
            if (axi_done_o) begin
                dirty_we[way_sel] = 1'b1;
                dirty_waddr[way_sel] = index;
                dirty_din[way_sel] = 1'b0;
            end
        end
        
        WRITE_BACK: begin
            // 写回完成后清除脏�?
            if (axi_done_o) begin
                dirty_we[way_sel] = 1'b1;
                dirty_waddr[way_sel] = index;
                dirty_din[way_sel] = 1'b0;
            end
        end
    endcase
end

// ============================================================================
// 组合逻辑赋�?? - AXI接口
// ============================================================================

always_comb begin
    axi_start_i = 1'b0;
    axi_wr_rd_i = 1'b0;
    axi_wr_wstrb_i = '0;
    axi_addr_i = 32'b0;
    axi_len_i = '0;
    axi_size_i = 3'b010; // 4字节传输
    axi_burst_i = 2'b01; // 增量突发
    axi_data_i = 32'b0;
    axi_use_array_i = 1'b0;
    
    case(curr_state)
        WRITE_BACK: begin
            axi_start_i = (curr_state == WRITE_BACK) && ~axi_busy_o;
            axi_wr_rd_i = 1'b1; // 写操�?
            axi_wr_wstrb_i = 4'b1111;
            // 构�?�内存地�?: tag + index + 0偏移
            axi_addr_i = {tag_way[way_sel], index, {OFFSET_BITS{1'b0}}};
            axi_len_i = (1 << OFFSET_BITS) - 1; // 突发长度 = 行大�?
            axi_use_array_i = 1'b1;
            
            // 将缓存行数据传�?�给AXI（这里需要根据数据存储输出构造）
            // 注意：这�?要根据实际的数据存储组织方式调整
            for (int i = 0; i < (1 << OFFSET_BITS); i++) begin
                axi_data_array_i[i] = data_dout[way_sel][32*i+:32];
            end
        end
        
        ALLOCATE: begin
            axi_start_i = (curr_state == ALLOCATE) && ~axi_busy_o;
            axi_wr_rd_i = 1'b0; // 读操�?
            axi_addr_i = {addr_buff[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
            axi_len_i = (1 << OFFSET_BITS) - 1; // 读取整个缓存�?
        end
    endcase
end

// ============================================================================
// 组合逻辑赋�?? - 主机接口
// ============================================================================

always_comb begin
    dout = '0;
    done = 1'b0;
    rvalid = 1'b0;
    error = 1'b0;
    busy = 1'b0;
    
    case(curr_state)
        IDLE: begin
            busy = start;
        end
        
        COMPARE: begin
            busy = 1'b1;
            if (hit) begin
                // 读命中：输出数据
                if (re_buff) begin
                    dout = data_dout[way_hit];
                    rvalid = 1'b1;
                end
                // 写命中：完成写入
                if (|we_buff) begin
                    done = 1'b1;
                end
                // 读或写都完成
                if (re_buff || (|we_buff)) begin
                    done = 1'b1;
                end
            end
        end
        
        RECOMPARE: begin
            busy = 1'b1;
            if (hit) begin
                // 分配后的读命�?
                if (re_buff) begin
                    dout = data_dout[way_hit];
                    rvalid = 1'b1;
                end
                done = 1'b1;
            end else begin
                error = 1'b1;
            end
        end
        
        REREAD: begin
            busy = 1'b1;
            if (hit) begin
                if (re_buff) begin
                    dout = data_dout[way_hit];
                    rvalid = 1'b1;
                end
                done = 1'b1;
            end
        end
        
        WRITE_BACK, ALLOCATE: begin
            busy = 1'b1;
        end
        
        ERROR: begin
            error = 1'b1;
            busy = 1'b1;
        end
        
        default: begin
            busy = 1'b0;
        end
    endcase
end


endmodule