module cache_way #(
    parameter TAG_BITS      =   14,     // TAG位宽
    parameter INDEX_BITS    =   12,     // 缓存深度，必须为2**INDEX_BITS
    parameter OFFSET_BITS   =   4,      // OFFSET位宽
    parameter WAY_NUM       =   4       // 表示缓存共多少路
)(
    input  logic                    clk,
    input  logic                    rst,

    // 数据存储接口
    input  logic [3:0]              data_we,
    input  logic [31:0]             data_addr,
    input  logic [31:0]             data_din,
    input  logic [31:0]             data_raddr,
    output logic [32*(1<<OFFSET_BITS)-1:0]  data_dout,

    // TagV存储接口
    input  logic                    tagv_we,
    input  logic [31:0]             tagv_addr_r,
    input  logic [31:0]             tagv_addr_w,
    output logic [TAG_BITS:0]       tagv_dout,
    
    // 脏位存储接口
    input  logic                    dirty_we,
    input  logic [INDEX_BITS-1:0]   dirty_waddr,
    input  logic                    dirty_din,
    input  logic [INDEX_BITS-1:0]   dirty_raddr,
    output logic                    dirty_dout
);

// 实例化数据存储模块
mem_data_way #(
    .TAG_BITS(TAG_BITS),
    .INDEX_BITS(INDEX_BITS),
    .OFFSET_BITS(OFFSET_BITS),
    .WAY_NUM(WAY_NUM)
) data_way_inst (
    .clk(clk),
    .rst(rst),
    .we(data_we),
    .addr(data_addr),  // 将索引扩展为32位地址
    .din(data_din),
    .raddr(data_raddr), // 将读索引扩展为32位地址
    .dout(data_dout)
);

// 实例化TagV存储模块
mem_tagv_way #(
    .TAG_BITS(TAG_BITS),
    .INDEX_BITS(INDEX_BITS),
    .OFFSET_BITS(OFFSET_BITS),
    .WAY_NUM(WAY_NUM)
) tagv_way_inst (
    .clk(clk),
    .rst(rst),
    .we(tagv_we),
    .addr_r(tagv_addr_r),
    .addr_w(tagv_addr_w),
    .dout(tagv_dout)
);

// 实例化脏位存储模块
mem_dirty #(
    .INDEX_BITS(INDEX_BITS)
) dirty_inst (
    .clk(clk),
    .rst(rst),
    .we(dirty_we),
    .waddr(dirty_waddr),
    .din(dirty_din),
    .raddr(dirty_raddr),
    .dout(dirty_dout)
);

endmodule