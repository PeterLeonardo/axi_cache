/*
默认参数下缓存地址的结构图：
    |31        18|17         6|5    2|1 0|
    |************|************|******|***|
    |   TAG      |   INDEX    |OFFSET|   |
*/
module mem_data_column #(
    parameter TAG_BITS      =   14,     //TAG位宽
    parameter INDEX_BITS    =   12,     //缓存深度，必须为2**INDEX_BITS
    parameter OFFSET_BITS   =   4,      //OFFSET位宽
    parameter WAY_NUM       =   4       //表示缓存共多少路
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic [3:0]              we,
    input  logic [INDEX_BITS-1:0]   addr,
    input  logic [31:0]             din,
    output logic [31:0]             dout
);

//注意：INDEX_BITS参数更改时，data_col_mem的深度也要更改为2**INDEX_BITS

data_col_mem data_col (
  .clka(clk),            // input wire clka
  .rsta(rst),            // input wire rsta
  .wea(we),              // input wire [3 : 0] wea
  .addra(addr),          // input wire [11 : 0] addra
  .dina(din),            // input wire [31 : 0] dina
  .douta(dout),          // output wire [31 : 0] douta
  .rsta_busy()           // output wire rsta_busy
);


endmodule
