module cache_top #(
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

    // ---------------- Host 接口 ----------------
    input  logic                    re,       // 读使能
    input  logic [3:0]              we,       // 写掩码
    input  logic [ADDR_WIDTH-1:0]   addr,     // 主机访问地址
    input  logic [DATA_WIDTH-1:0]   din,      // 主机写数据
    output logic [DATA_WIDTH*READ_WORDS-1:0] dout, // 主机读数据
    output logic                    done,     // 操作完成信号
    output logic                    rvalid,   // 读数据有效
    output logic                    error,    // 错误信号
    input  logic                    restart,  // 重启信号
    output logic                    busy,     // 忙状态

    // ---------------- AXI 总线接口 ----------------
    axi_master_if.master            axi_bus
);

    // ============================================================
    // 一、内部信号定义
    // ============================================================

    // 数据 BRAM 接口信号
    logic [WAY_NUM-1:0][3:0]               data_we;
    logic [WAY_NUM-1:0][ADDR_WIDTH-1:0]    data_addr;
    logic [WAY_NUM-1:0][DATA_WIDTH-1:0]    data_din;
    logic [WAY_NUM-1:0][ADDR_WIDTH-1:0]    data_raddr;
    logic [WAY_NUM-1:0][DATA_WIDTH*(1<<OFFSET_BITS)-1:0] data_dout;

    // Tag+Valid 接口信号
    logic [WAY_NUM-1:0]                    tagv_we;
    logic [WAY_NUM-1:0][ADDR_WIDTH-1:0]    tagv_addr_r;
    logic [WAY_NUM-1:0][ADDR_WIDTH-1:0]    tagv_addr_w;
    logic [WAY_NUM-1:0][TAG_BITS:0]        tagv_dout;

    // 脏位接口信号
    logic [WAY_NUM-1:0]                    dirty_we;
    logic [WAY_NUM-1:0][INDEX_BITS-1:0]    dirty_waddr;
    logic [WAY_NUM-1:0]                    dirty_din;
    logic [WAY_NUM-1:0][INDEX_BITS-1:0]    dirty_raddr;
    logic [WAY_NUM-1:0]                    dirty_dout;

    // AXI 控制信号
    logic                            axi_start_i;
    logic                            axi_wr_rd_i;
    logic [DATA_WIDTH/8-1:0]         axi_wr_wstrb_i;
    logic [ADDR_WIDTH-1:0]           axi_addr_i;
    logic [BURST_LEN_WIDTH-1:0]      axi_len_i;
    logic [2:0]                      axi_size_i;
    logic [1:0]                      axi_burst_i;
    logic [DATA_WIDTH-1:0]           axi_data_i;
    logic [DATA_WIDTH-1:0]           axi_data_array_i [MAX_BURST_LEN];
    logic                            axi_use_array_i;
    logic                            axi_done_o;
    logic [DATA_WIDTH-1:0]           axi_data_o;
    logic                            axi_data_valid_o;
    logic [1:0]                      axi_resp_o;
    logic                            axi_error_o;
    logic                            axi_busy_o;

    // 命中控制信号
    logic                            cache_hit;
    logic [$clog2(WAY_NUM)-1:0]      way_hit;
    logic [$clog2(WAY_NUM)-1:0]      way_sel;

    // ============================================================
    // 二、实例化 cache_ctrl 主控制器
    // ============================================================
    cache_ctrl #(
        .READ_WORDS(READ_WORDS),
        .TAG_BITS(TAG_BITS),
        .INDEX_BITS(INDEX_BITS),
        .OFFSET_BITS(OFFSET_BITS),
        .WAY_NUM(WAY_NUM),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BURST_LEN_WIDTH(BURST_LEN_WIDTH),
        .MAX_BURST_LEN(MAX_BURST_LEN),
        .ID_WIDTH(ID_WIDTH),
        .REGION_WIDTH(REGION_WIDTH)
    ) u_cache_ctrl (
        .clk(clk),
        .rst(rst),

        // ---------- 主机接口 ----------
        .re(re),
        .we(we),
        .addr(addr),
        .din(din),
        .dout(dout),
        .done(done),
        .rvalid(rvalid),
        .error(error),
        .restart(restart),
        .busy(busy),

        // ---------- 数据存储接口 ----------
        .data_we(data_we),
        .data_addr(data_addr),
        .data_din(data_din),
        .data_raddr(data_raddr),
        .data_dout(data_dout),

        // ---------- TagV 接口 ----------
        .tagv_we(tagv_we),
        .tagv_addr_r(tagv_addr_r),
        .tagv_addr_w(tagv_addr_w),
        .tagv_dout(tagv_dout),

        // ---------- 脏位接口 ----------
        .dirty_we(dirty_we),
        .dirty_waddr(dirty_waddr),
        .dirty_din(dirty_din),
        .dirty_raddr(dirty_raddr),
        .dirty_dout(dirty_dout),

        // ---------- AXI 控制接口 ----------
        .axi_start_i(axi_start_i),
        .axi_wr_rd_i(axi_wr_rd_i),
        .axi_wr_wstrb_i(axi_wr_wstrb_i),
        .axi_addr_i(axi_addr_i),
        .axi_len_i(axi_len_i),
        .axi_size_i(axi_size_i),
        .axi_burst_i(axi_burst_i),
        .axi_data_i(axi_data_i),
        .axi_data_array_i(axi_data_array_i),
        .axi_use_array_i(axi_use_array_i),
        .axi_done_o(axi_done_o),
        .axi_data_o(axi_data_o),
        .axi_data_valid_o(axi_data_valid_o),
        .axi_resp_o(axi_resp_o),
        .axi_error_o(axi_error_o),
        .axi_busy_o(axi_busy_o),

        // ---------- 命中控制 ----------
        .cache_hit(cache_hit),
        .way_hit(way_hit),
        .way_sel(way_sel)
    );

    // ============================================================
    // 三、实例化 WAY_NUM 个 cache_way 模块
    // ============================================================
    genvar i;
    generate
        for (i = 0; i < WAY_NUM; i++) begin : gen_cache_way
            cache_way #(
                .TAG_BITS(TAG_BITS),
                .INDEX_BITS(INDEX_BITS),
                .OFFSET_BITS(OFFSET_BITS),
                .WAY_NUM(WAY_NUM)
            ) u_cache_way (
                .clk(clk),
                .rst(rst),

                // ---------- 数据 BRAM ----------
                .data_we(data_we[i]),
                .data_addr(data_addr[i][INDEX_BITS-1:0]),  // 地址低位部分
                .data_din(data_din[i]),
                .data_raddr(data_raddr[i][INDEX_BITS-1:0]),
                .data_dout(data_dout[i]),

                // ---------- TagV ----------
                .tagv_we(tagv_we[i]),
                .tagv_addr_r(tagv_addr_r[i]),
                .tagv_addr_w(tagv_addr_w[i]),
                .tagv_dout(tagv_dout[i]),

                // ---------- Dirty ----------
                .dirty_we(dirty_we[i]),
                .dirty_waddr(dirty_waddr[i]),
                .dirty_din(dirty_din[i]),
                .dirty_raddr(dirty_raddr[i]),
                .dirty_dout(dirty_dout[i])
            );
        end
    endgenerate

    // ============================================================
    // 四、实例化路选择模块 cache_waysel
    // ============================================================
    cache_waysel #(
        .WAY_NUM_LOG2($clog2(WAY_NUM))
    ) u_cache_waysel (
        .clk(clk),
        .rst(rst),
        .cache_hit(cache_hit),
        .way_hit(way_hit),
        .way_sel(way_sel)
    );

    // ============================================================
    // 五、实例化 AXI 主控驱动模块
    // ============================================================
    axi_master_driver #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BURST_LEN_WIDTH(BURST_LEN_WIDTH),
        .MAX_BURST_LEN(MAX_BURST_LEN),
        .ID_WIDTH(ID_WIDTH),
        .REGION_WIDTH(REGION_WIDTH)
    ) u_axi_master_driver (
        .axi_bus(axi_bus),

        // ---------- 控制输入 ----------
        .start_i(axi_start_i),
        .wr_rd_i(axi_wr_rd_i),
        .wr_wstrb_i(axi_wr_wstrb_i),
        .addr_i(axi_addr_i),
        .len_i(axi_len_i),
        .size_i(axi_size_i),
        .burst_i(axi_burst_i),
        .data_i(axi_data_i),
        .data_array_i(axi_data_array_i),
        .use_array_i(axi_use_array_i),

        // ---------- 状态输出 ----------
        .done_o(axi_done_o),
        .data_o(axi_data_o),
        .data_valid_o(axi_data_valid_o),
        .resp_o(axi_resp_o),
        .error_o(axi_error_o),
        .busy_o(axi_busy_o)
    );

endmodule
