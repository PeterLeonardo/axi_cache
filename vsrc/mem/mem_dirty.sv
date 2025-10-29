module mem_dirty #(
    parameter INDEX_BITS = 12
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    we,           // 写使能
    input  logic [INDEX_BITS-1:0]   waddr,        // 写地址
    input  logic                    din,          // 写数据（1位）
    input  logic [INDEX_BITS-1:0]   raddr,        // 读地址
    output logic                    dout          // 读数据（1位）
);

// 使用Block RAM实现脏位存储
// 深度：2**INDEX_BITS，宽度：1位

// BRAM存储阵列
(* ram_style = "block" *) logic [0:0] bram [0:(1<<INDEX_BITS)-1];

// 写操作
always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < (1<<INDEX_BITS); i++) begin
            bram[i] = 1'b0;
        end
    end else if (we) begin
        bram[waddr] <= din;
    end
end

// 读操作
always_ff @(posedge clk) begin
    if (rst) begin
        dout <= 1'b0;
    end else begin
        dout <= bram[raddr];
    end
end

endmodule