module mem_tagv_way #(
    parameter TAG_BITS      =   14,     // TAG位宽
    parameter INDEX_BITS    =   12,     // 缓存深度，必须为2**INDEX_BITS
    parameter OFFSET_BITS   =   4,      // OFFSET位宽
    parameter WAY_NUM       =   4       // 表示缓存共多少路
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    we,
    input  logic [31:0]             addr_r,
    input  logic [31:0]             addr_w,
    output logic [TAG_BITS:0]       dout  // 位宽
);

logic [1:0]             raddr_bitOffset;
logic [OFFSET_BITS-1:0] raddr_offset;
logic [INDEX_BITS-1:0]  raddr_index;
logic [TAG_BITS-1:0]    raddr_tag;
logic [1:0]             waddr_bitOffset;
logic [OFFSET_BITS-1:0] waddr_offset;
logic [INDEX_BITS-1:0]  waddr_index;
logic [TAG_BITS-1:0]    waddr_tag;

logic [INDEX_BITS-1:0]  addr_in;
logic [TAG_BITS:0]      tagv_in;

always_comb begin : addr_decode
    raddr_bitOffset  = addr_r[1:0];
    raddr_offset     = addr_r[OFFSET_BITS+1:2];
    raddr_index      = addr_r[INDEX_BITS+OFFSET_BITS+1:OFFSET_BITS+2];
    raddr_tag        = addr_r[31:INDEX_BITS+OFFSET_BITS+2];
    waddr_bitOffset  = addr_w[1:0];
    waddr_offset     = addr_w[OFFSET_BITS+1:2];
    waddr_index      = addr_w[INDEX_BITS+OFFSET_BITS+1:OFFSET_BITS+2];
    waddr_tag        = addr_w[31:INDEX_BITS+OFFSET_BITS+2];
end

always_comb begin
    addr_in = we ? waddr_index : raddr_index;
    tagv_in = {1'b1, waddr_tag};
end

tagv_col_mem tagv_col (
  .clka(clk),            // input wire clka
  .rsta(rst),            // input wire rsta
  .wea(we),              // input wire [0 : 0] wea
  .addra(addr_in),          // input wire [11 : 0] addra
  .dina(tagv_in),            // input wire [14 : 0] dina
  .douta(dout),          // output wire [14 : 0] douta
  .rsta_busy(rsta_busy)  // output wire rsta_busy
);

endmodule