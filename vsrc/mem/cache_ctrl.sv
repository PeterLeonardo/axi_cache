module cache_ctrl #(
    parameter READ_WORDS    = 4,
    parameter TAG_BITS      = 14,
    parameter INDEX_BITS    = 12,
    parameter OFFSET_BITS   = 4,
    parameter WAY_NUM       = 4,
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter BURST_LEN_WIDTH = 8,
    parameter MAX_BURST_LEN   = 16,
    parameter ID_WIDTH        = 1,
    parameter REGION_WIDTH    = 4
)(
    input  logic                    clk,
    input  logic                    rst,

    // Host interface
    input  logic                    re,
    input  logic [3:0]              we,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   din,
    output logic [DATA_WIDTH*READ_WORDS-1:0] dout,
    output logic                    done,
    output logic                    rvalid,
    output logic                    error,
    input  logic                    restart,
    output logic                    busy,

    // Data storage interface (WAY_NUM BRAMs)
    output logic [WAY_NUM-1:0] [3:0]            data_we,
    output logic [WAY_NUM-1:0] [ADDR_WIDTH-1:0] data_addr,
    output logic [WAY_NUM-1:0] [DATA_WIDTH-1:0] data_din,
    output logic [WAY_NUM-1:0] [ADDR_WIDTH-1:0] data_raddr,
    input  logic [WAY_NUM-1:0] [DATA_WIDTH*(1<<OFFSET_BITS)-1:0] data_dout,

    // Tag+Valid storage interface
    output logic [WAY_NUM-1:0]                  tagv_we,
    output logic [WAY_NUM-1:0] [ADDR_WIDTH-1:0] tagv_addr_r,
    output logic [WAY_NUM-1:0] [ADDR_WIDTH-1:0] tagv_addr_w,
    input  logic [WAY_NUM-1:0] [TAG_BITS:0]     tagv_dout,

    // Dirty bit storage interface
    output logic [WAY_NUM-1:0]                  dirty_we,
    output logic [WAY_NUM-1:0] [INDEX_BITS-1:0] dirty_waddr,
    output logic [WAY_NUM-1:0]                  dirty_din,
    output logic [WAY_NUM-1:0] [INDEX_BITS-1:0] dirty_raddr,
    input  logic [WAY_NUM-1:0]                  dirty_dout,

    // AXI interface
    output logic                            axi_start_i,
    output logic                            axi_wr_rd_i,    // 0=read, 1=write
    output logic [DATA_WIDTH/8-1:0]         axi_wr_wstrb_i,
    output logic [ADDR_WIDTH-1:0]           axi_addr_i,
    output logic [BURST_LEN_WIDTH-1:0]      axi_len_i,
    output logic [2:0]                      axi_size_i,
    output logic [1:0]                      axi_burst_i,
    output logic [DATA_WIDTH-1:0]           axi_data_i,
    output logic [DATA_WIDTH-1:0]           axi_data_array_i [MAX_BURST_LEN],
    output logic                            axi_use_array_i,
    input  logic                            axi_done_o,
    input  logic [DATA_WIDTH-1:0]           axi_data_o,
    input  logic                            axi_data_valid_o,
    input  logic [1:0]                      axi_resp_o,
    input  logic                            axi_error_o,
    input  logic                            axi_busy_o,

    // Way select logic
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

cache_state_t curr_state, next_state;

// Internal signals
logic           start;
logic [ADDR_WIDTH-1:0] addr_ahead;
logic [ADDR_WIDTH-1:0] addr_buff, addr_ahead_buff;
logic [DATA_WIDTH-1:0] din_buff;
logic           re_buff;
logic [3:0]     we_buff;
logic           re_buff_buff;
logic [3:0]     we_buff_buff;
logic           row_diff;
logic           row_diff_buff;
logic [$clog2(WAY_NUM)-1:0] way_sel_buff;
logic [DATA_WIDTH*(1<<OFFSET_BITS)-1:0] data_dout_buff[MAX_BURST_LEN];
logic [DATA_WIDTH*(1<<OFFSET_BITS)-1:0] data_reread_buff;

logic [TAG_BITS-1:0] tag;
logic [INDEX_BITS-1:0] index;
logic [OFFSET_BITS-1:0] offset;
logic [1:0]     byte_offset;

//control signals
logic           signal_write;
logic           signal_allocate;
logic           signal_reallocate;
logic           signal_writeback;
logic           signal_reread;
logic           signal_recompare;


// Decode address fields
assign tag = addr_buff[31 : INDEX_BITS + OFFSET_BITS + 2];
assign index = addr_buff[INDEX_BITS + OFFSET_BITS + 1 : OFFSET_BITS + 2];
assign offset = addr_buff[OFFSET_BITS + 1 : 2];
assign byte_offset = addr_buff[1:0];

// Way hit logic (based on tag+valid)
logic [WAY_NUM-1:0] valid_way;
logic [WAY_NUM-1:0][TAG_BITS-1:0] tag_way;
logic [WAY_NUM-1:0] hit_way;
always_comb begin
    for (int i = 0; i < WAY_NUM; i++) begin
        valid_way[i] = tagv_dout[i][TAG_BITS];
        tag_way[i] = tagv_dout[i][TAG_BITS-1:0];
        hit_way[i] = valid_way[i] && (tag_way[i] == tag);
    end
end
assign cache_hit = |hit_way;
logic [$clog2(WAY_NUM)-1:0] way_hit_int;
always_comb begin
    way_hit_int = '0;
    for (int i = 0; i < WAY_NUM; i++) begin
        if (hit_way[i]) way_hit_int = i;
    end
end
assign start = re | (|we);
assign way_hit = way_hit_int;
assign addr_ahead = addr + READ_WORDS * 4;

// Pipeline inputs from host
//common buffer
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        addr_buff       <= 0;
        addr_ahead_buff <= 0;
        din_buff        <= 0;
        re_buff         <= 0;
        we_buff         <= 0;
        re_buff_buff    <= 0;
        we_buff_buff    <= 0;
        row_diff_buff   <= 0;
    end else if (start && ~busy) begin
        addr_buff        <= addr;
        addr_ahead_buff  <= addr + READ_WORDS * 4;
        din_buff         <= din;
        re_buff          <= re;
        we_buff          <= we;
        re_buff_buff     <= re_buff;
        we_buff_buff     <= we_buff;
        row_diff_buff    <= addr_ahead[OFFSET_BITS+2] ^ addr[OFFSET_BITS+2];
    end
end

//allocate buffer
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        way_sel_buff <= '0;
    end else if (start && ~busy) begin
        way_sel_buff <= way_sel;
    end
end

//writeback buffer
always_ff @( posedge clk or posedge rst ) begin
    if(rst) begin
        for(int i = 0; i < (1<<OFFSET_BITS); i++) begin
            data_dout_buff[i] <= '0;
        end
    end
    else if(signal_writeback) begin
        for(int i = 0; i < (1<<OFFSET_BITS); i++) begin
            data_dout_buff[i] <= data_dout[i];
        end
    end
end

//reread buffer
always_ff @( posedge clk or posedge rst ) begin
    if(rst) begin
        data_reread_buff <= '0;
    end
    else if(signal_reread) begin
        data_reread_buff <= data_dout[way_hit_int];
    end
end


// State register
always_ff @(posedge clk or posedge rst) begin
    if (rst) curr_state <= IDLE;
    else curr_state <= next_state;
end

// State transitions (keep as original structure)
always_comb begin
    next_state = curr_state;
    case (curr_state)
        IDLE: if (start) next_state = COMPARE;
        COMPARE: begin
            if (cache_hit) begin
                if (row_diff_buff && re_buff) next_state = REREAD;
                else if (start) next_state = COMPARE;
                else next_state = IDLE;
            end else begin
                if (dirty_dout[way_sel]) begin
                    next_state = WRITE_BACK;
                end else begin
                    next_state = ALLOCATE;
                end
            end
        end
        WRITE_BACK: begin
            if (axi_error_o) next_state = ERROR;
            else if (axi_done_o) next_state = ALLOCATE;
        end
        ALLOCATE: begin
            if (axi_error_o) next_state = ERROR;
            else if (axi_done_o) next_state = RECOMPARE;
        end
        RECOMPARE: begin
            if (cache_hit) begin
                if (row_diff_buff && re_buff) next_state = REREAD;
                else if (start) next_state = COMPARE;
                else next_state = IDLE;
            end else next_state = ERROR;
        end
        REREAD: begin
            if (cache_hit) begin
                if (start) next_state = COMPARE;
                else next_state = IDLE;
            end else begin
                // similar logic for miss
                if (|we_buff) next_state = WRITE_BACK;
                else next_state = ALLOCATE;
            end
        end
        ERROR: begin
            if (restart) next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

//signal control
always_comb begin
    signal_write = 1'b0;
    signal_allocate = 1'b0;
    signal_writeback = 1'b0;
    signal_reread = 1'b0;
    signal_recompare = 1'b0;
    signal_reallocate = 1'b0;
    case (curr_state)
        COMPARE: begin
            if (cache_hit) begin
                if (|we_buff) signal_write = 1'b1;
                else if (row_diff_buff && re_buff) signal_reread = 1'b1;
            end else begin
                if (dirty_dout[way_sel]) begin
                    signal_writeback = 1'b1;
                end else begin
                    signal_allocate = 1'b1;
                end
            end
        end
        WRITE_BACK: begin
            if (axi_done_o) signal_allocate = 1'b1;
        end
        ALLOCATE: begin
            if (axi_done_o) signal_recompare = 1'b1;
        end
        RECOMPARE: begin
            if (cache_hit) begin
                if (|we_buff) signal_write = 1'b1;
                else if (row_diff_buff && re_buff) signal_reread = 1'b1;
            end
        end
        REREAD: begin
            if (cache_hit) begin
            end else begin
                if (|we_buff) signal_writeback = 1'b1;
                else begin signal_allocate = 1'b1; signal_reallocate = 1'b1; end
            end
        end
        default: ;
    endcase
end
//=============================================================================
// Data Array Interface

// Offset counter for line fill writes
logic [OFFSET_BITS-1:0] alloc_offset_reg;
always_ff @(posedge clk or posedge rst) begin
    if (rst) alloc_offset_reg <= 0;
    else if (curr_state == ALLOCATE && axi_data_valid_o) alloc_offset_reg <= alloc_offset_reg + 1;
    else if (curr_state != ALLOCATE) alloc_offset_reg <= 0;
end

//burst counter
logic           signal_reallocate_hold;
logic [$clog2(MAX_BURST_LEN):0]   burst_cnt;
always_ff @( posedge clk or posedge rst ) begin
    if(rst | signal_allocate) begin
        burst_cnt <= '0;
    end
    else if(curr_state==ALLOCATE && axi_data_valid_o) begin
        burst_cnt <= burst_cnt + 1'b1;
    end
end
always_ff @( posedge clk or posedge rst ) begin
    if(rst | axi_done_o) begin
        signal_reallocate_hold <= 0;
    end
    else if(signal_reallocate) begin
        signal_reallocate_hold <= 1'b1;
    end
end
always_comb begin

    for(int i = 0; i < WAY_NUM; i = i+1) begin
        if(signal_reread) begin
            data_raddr[i] = addr_ahead_buff;
        end else if(signal_recompare) begin
            data_raddr[i] = addr_buff;
        end else begin
            data_raddr[i] = addr;
        end
    end

    data_we   = '0;
    data_addr = '{default: 0};
    data_din  = '{default: 0};
    if(signal_write) begin
        data_we[way_hit_int]    = we_buff;
        data_addr[way_hit_int]  = addr_buff;
        data_din[way_hit_int]   = din_buff;
    end else if(curr_state==ALLOCATE && ~signal_reallocate_hold) begin
        data_we[way_sel_buff]   = 4'b1111 & {4{axi_data_valid_o}};
        data_addr[way_sel_buff] = {addr_buff[31:$clog2(MAX_BURST_LEN)+2], burst_cnt[$clog2(MAX_BURST_LEN)-1:0] , 2'b00};
        data_din[way_sel_buff]  = axi_data_o;
    end else if(curr_state==ALLOCATE && signal_reallocate_hold) begin
        data_we[way_sel_buff]   = 4'b1111 & {4{axi_data_valid_o}};
        data_addr[way_sel_buff] = {addr_ahead_buff[31:$clog2(MAX_BURST_LEN)+2], burst_cnt[$clog2(MAX_BURST_LEN)-1:0] , 2'b00};
        data_din[way_sel_buff]  = axi_data_o;
    end
end

//=============================================================================
// Tag/Valid Array Interface

always_comb begin

    // Always read the tag for current index
    for(int i = 0; i < WAY_NUM; i = i+1) begin
        if(signal_reread) begin
            tagv_addr_r[i] = addr_ahead_buff;
        end else if(signal_recompare) begin
            tagv_addr_r[i] = addr_buff;
        end else begin
            tagv_addr_r[i] = addr;
        end
    end

    tagv_we    = '0;
    tagv_addr_w = '{default: 0};
    if(signal_allocate && ~signal_reallocate) begin
        tagv_we[way_sel_buff] = 1'b1;
        tagv_addr_w[way_sel_buff] = addr_buff;
    end else if(signal_allocate && signal_reallocate) begin
        tagv_we[way_sel_buff] = 1'b1;
        tagv_addr_w[way_sel_buff] = addr_ahead_buff;
    end

end

//=============================================================================
// Dirty Bit Array Interface

always_comb begin
    dirty_we    = '0;
    dirty_waddr = '{default: 0};
    dirty_din   = '0;
    dirty_raddr = '{default: 0};

    // Always read current dirty bits
    for (int i = 0; i < WAY_NUM; i++) begin
        dirty_raddr[i] = index;
    end

    case (curr_state)
        COMPARE: begin
            // On write hit, set dirty bit for that way
            if (cache_hit && (|we_buff)) begin
                dirty_we[way_hit_int]    = 1'b1;
                dirty_waddr[way_hit_int] = index;
                dirty_din[way_hit_int]   = 1'b1;
            end
        end

        ALLOCATE: begin
            // After filling new line, clear dirty bit for that way (D=0 on allocate)
            if (axi_done_o) begin
                dirty_we[way_sel]    = 1'b1;
                dirty_waddr[way_sel] = index;
                dirty_din[way_sel]   = 1'b0;
            end
        end

        WRITE_BACK: begin
            // After write-back, clear dirty bit as line is clean
            if (axi_done_o) begin
                dirty_we[way_sel]    = 1'b1;
                dirty_waddr[way_sel] = index;
                dirty_din[way_sel]   = 1'b0;
            end
        end

        default: begin
            // No dirty writes in other states
        end
    endcase
end

//=============================================================================
// AXI Interface Control

always_comb begin
    axi_start_i   = 1'b0;
    axi_wr_rd_i   = 1'b0;
    axi_wr_wstrb_i= '0;
    axi_addr_i    = '0;
    axi_len_i     = '0;
    axi_size_i    = 3'b010; // 4-byte transfers
    axi_burst_i   = 2'b01;  // INCR burst
    axi_data_i    = '0;
    axi_use_array_i = 1'b0;

    for (int i = 0; i < MAX_BURST_LEN; i++) begin
        axi_data_array_i[i] = '0;
    end

    case (curr_state)
        WRITE_BACK: begin
            axi_start_i = ~axi_busy_o;
            axi_wr_rd_i = 1'b1;
            axi_wr_wstrb_i = {DATA_WIDTH/8{1'b1}};
            // Align address to start of cache line
            axi_addr_i = { tag_way[way_sel_buff], index, {(OFFSET_BITS+2){1'b0}} };
            axi_len_i  = (1 << OFFSET_BITS) - 1;  // burst length = line size
            axi_use_array_i = 1'b1;
            // Load data array into AXI write buffer
            for (int i = 0; i < (1<<OFFSET_BITS); i++) begin
                axi_data_array_i[i] = data_dout_buff[way_sel_buff][DATA_WIDTH*i +: DATA_WIDTH];
            end
        end

        ALLOCATE: begin
            axi_start_i = ~axi_busy_o;
            axi_wr_rd_i = 1'b0;              // read from memory
            // Align read to start of block
            if(signal_reallocate_hold) begin
                axi_addr_i = { addr_ahead_buff[31:OFFSET_BITS+2], {(OFFSET_BITS+2){1'b0}} };
            end else begin
                axi_addr_i = { addr_buff[31:OFFSET_BITS+2], {(OFFSET_BITS+2){1'b0}} };
            end
            axi_len_i  = (1 << OFFSET_BITS) - 1;
            axi_use_array_i = 1'b0;
        end

        default: begin
            // No AXI operation
        end
    endcase
end

//=============================================================================
// Host Response Logic

function automatic logic [READ_WORDS*DATA_WIDTH-1:0]
    get_line_slice(
        input logic [DATA_WIDTH*(1<<OFFSET_BITS)-1:0] line_data,
        input logic [OFFSET_BITS-1:0]                 offset,
        input logic [1:0]                             byte_offset
    );

    // 拼接偏移量：offset<<2 + byte_offset
    logic [OFFSET_BITS+1:0] start_byte;    
    logic [OFFSET_BITS+4:0] shift_bits;    
    logic [DATA_WIDTH*(1<<OFFSET_BITS)-1:0] shifted_line;

begin
    // byte偏移 = offset * 4 + byte_offset，用拼接实现
    start_byte = {offset, byte_offset};

    // 位偏移 = byte偏移 * 8，用拼接实现
    shift_bits = {start_byte, 3'b000};

    // 右移得到目标字节段（组合逻辑 barrel-shift）
    shifted_line = line_data >> shift_bits;

    // 取出READ_WORDS个word
    get_line_slice = shifted_line[READ_WORDS*DATA_WIDTH-1:0];
end
endfunction

// =====================================================
// 拼接两个cache line数据，从line_hi的offset开始，
// 取完高行剩余部分后继续从line_lo补齐。
// =====================================================
function automatic logic [READ_WORDS*DATA_WIDTH-1:0]
    join_two_lines(
        input logic [DATA_WIDTH*(1<<OFFSET_BITS)-1:0] line_hi,
        input logic [DATA_WIDTH*(1<<OFFSET_BITS)-1:0] line_lo,
        input logic [OFFSET_BITS-1:0]                 offset,
        input logic [1:0]                             byte_offset
    );

    // ---------------------------
    // 常量定义
    // ---------------------------
    localparam int LINE_BYTES = (1 << OFFSET_BITS) * 4;
    localparam int LINE_BITS  = LINE_BYTES * 8;
    localparam int OUT_BYTES  = READ_WORDS * 4;
    localparam int OUT_BITS   = OUT_BYTES * 8;

    // ---------------------------
    // 位拼接实现
    // ---------------------------
    logic [OFFSET_BITS+1:0] start_byte;
    logic [LINE_BITS*2-1:0] merged_data;
    logic [OFFSET_BITS+4:0] shift_bits;
    logic [LINE_BITS*2-1:0] merged_data_right;
begin
    // 计算偏移
    start_byte = {offset, byte_offset};
    shift_bits = {start_byte, 3'b000};  // 相当于 *8

    // 拼接为连续的2倍长度数据
    merged_data = {line_hi, line_lo};

    // 向右移实现从start_byte开始读取
    merged_data_right = merged_data >> shift_bits;

    // 截取输出位宽
    join_two_lines = merged_data_right[OUT_BITS-1:0];
end
endfunction


always_comb begin
    case (curr_state)
        IDLE: begin
            dout = '0;
            done = 1'b0;
            rvalid = 1'b0;
            error = 1'b0;
            busy = 1'b0;
        end

        COMPARE: begin
            if (cache_hit) begin
                if (row_diff_buff && re_buff) begin
                    dout = '0;
                    done = 1'b0;
                    rvalid = 1'b0;
                    error = 1'b0;
                    busy = 1'b1;
                end else begin 
                    dout = get_line_slice(data_dout[way_hit_int], offset, byte_offset);
                    done = 1'b1;
                    rvalid = re_buff;
                    error = 1'b0;
                    busy = 1'b0;
                end
            end else begin
                dout = '0;
                done = 1'b0;
                rvalid = 1'b0;
                error = 1'b0;
                busy = 1'b1;
            end
        end
        
        REREAD: begin
            if (cache_hit) begin
                dout = join_two_lines(data_dout[way_hit_int], data_reread_buff, offset, byte_offset);
                done = 1'b1;
                rvalid = 1'b1;
                error = 1'b0;
                busy = 1'b0;
            end else begin
                dout = '0;
                done = 1'b0;
                rvalid = 1'b0;
                error = 1'b0;
                busy = 1'b1;
            end
        end
        RECOMPARE: begin
            if (cache_hit) begin
                if (row_diff_buff && re_buff) begin
                    dout = '0;
                    done = 1'b0;
                    rvalid = 1'b0;
                    error = 1'b0;
                    busy = 1'b1;
                end else begin 
                    dout = get_line_slice(data_dout[way_hit_int], offset, byte_offset);
                    done = 1'b1;
                    rvalid = re_buff;
                    error = 1'b0;
                    busy = 1'b0;
                end
            end else begin
                dout = '0;
                done = 1'b0;
                rvalid = 1'b0;
                error = 1'b0;
                busy = 1'b0;
            end
        end

        WRITE_BACK, ALLOCATE: begin
            dout = '0;
            done = 1'b0;
            rvalid = 1'b0;
            error = 1'b0;
            busy = 1'b1;
        end

        ERROR: begin
            dout = '0;
            done = 1'b0;
            rvalid = 1'b0;
            error = 1'b1;
            busy = 1'b1;
        end

        default: begin
            dout = '0;
            done = 1'b0;
            rvalid = 1'b0;
            error = 1'b0;
            busy = 1'b0;
        end
    endcase
end

endmodule
