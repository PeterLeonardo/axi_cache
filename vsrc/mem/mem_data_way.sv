module mem_data_way #(
    parameter TAG_BITS      =   14,     // TAG位宽
    parameter INDEX_BITS    =   12,     // 缓存深度，必须为2**INDEX_BITS
    parameter OFFSET_BITS   =   4,      // OFFSET位宽
    parameter WAY_NUM       =   4       // 表示缓存共多少路
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic [3:0]              we,
    input  logic [31:0]             addr,
    input  logic [31:0]             din,
    output logic [32*(1<<OFFSET_BITS)-1:0]  dout  // 位宽
);

localparam COL_NUM = 1<<OFFSET_BITS;

logic [1:0]             addr_bitOffset;
logic [OFFSET_BITS-1:0] addr_offset;
logic [INDEX_BITS-1:0]  addr_index;
logic [TAG_BITS-1:0]    addr_tag;

logic [31:0]            din_tran;
logic [3:0]             we_tran;

always_comb begin : addr_decode
    addr_bitOffset  = addr[1:0];
    addr_offset     = addr[OFFSET_BITS+1:2];
    addr_index      = addr[INDEX_BITS+OFFSET_BITS+1:OFFSET_BITS+2];
    addr_tag        = addr[31:INDEX_BITS+OFFSET_BITS+2];

    din_tran        = din << {addr_bitOffset, 3'b0};  // 字节移位（×8）
    we_tran         = we << addr_bitOffset;
end

genvar column_index;
generate
    for(column_index = 0; column_index < COL_NUM; column_index = column_index+1) begin : data_col_mem
        mem_data_column #(
            .TAG_BITS(TAG_BITS),
            .INDEX_BITS(INDEX_BITS), 
            .OFFSET_BITS(OFFSET_BITS),
            .WAY_NUM(WAY_NUM)
        ) data_column_inst (
            .clk(clk),
            .rst(rst),
            .we(we_tran),
            .addr(addr_index),
            .din(din_tran),
            .dout(dout[32*column_index+31:32*column_index])
        );
    end
endgenerate

endmodule