module cache_example #(
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
    output logic                    busy      // 忙状态
);

    // =========================================================================
    // AXI 接口定义
    // =========================================================================
    axi_master_if master_if(.aclk(clk), .aresetn(~rst));

    // =========================================================================
    // DUT 实例化：cache_top
    // =========================================================================
    cache_top #(
        .READ_WORDS     (READ_WORDS),
        .TAG_BITS       (TAG_BITS),
        .INDEX_BITS     (INDEX_BITS),
        .OFFSET_BITS    (OFFSET_BITS),
        .WAY_NUM        (WAY_NUM),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .BURST_LEN_WIDTH(BURST_LEN_WIDTH),
        .MAX_BURST_LEN  (MAX_BURST_LEN),
        .ID_WIDTH       (ID_WIDTH),
        .REGION_WIDTH   (REGION_WIDTH)
    ) u_cache_top (
        .clk        (clk),
        .rst        (rst),

        // Host 接口
        .re         (re),
        .we         (we),
        .addr       (addr),
        .din        (din),
        .dout       (dout),
        .done       (done),
        .rvalid     (rvalid),
        .error      (error),
        .restart    (restart),
        .busy       (busy),

        // AXI 接口
        .axi_bus    (master_if)
    );

    // =========================================================================
    // AXI BRAM Controller 实例
    // =========================================================================
    axi_bram_ctrl_0 u_axi_bram_ctrl (
        .s_axi_aclk    (clk),
        .s_axi_aresetn (~rst),

        // AXI 接口连接到 master_if
        .s_axi_araddr  (master_if.m_axi_araddr[14:0]),
        .s_axi_arburst (master_if.m_axi_arburst),
        .s_axi_arcache (master_if.m_axi_arcache),
        .s_axi_arlen   (master_if.m_axi_arlen),
        .s_axi_arlock  (master_if.m_axi_arlock),
        .s_axi_arprot  (master_if.m_axi_arprot),
        .s_axi_arready (master_if.m_axi_arready),
        .s_axi_arsize  (master_if.m_axi_arsize),
        .s_axi_arvalid (master_if.m_axi_arvalid),

        .s_axi_awaddr  (master_if.m_axi_awaddr[14:0]),
        .s_axi_awburst (master_if.m_axi_awburst),
        .s_axi_awcache (master_if.m_axi_awcache),
        .s_axi_awlen   (master_if.m_axi_awlen),
        .s_axi_awlock  (master_if.m_axi_awlock),
        .s_axi_awprot  (master_if.m_axi_awprot),
        .s_axi_awready (master_if.m_axi_awready),
        .s_axi_awsize  (master_if.m_axi_awsize),
        .s_axi_awvalid (master_if.m_axi_awvalid),

        .s_axi_bready  (master_if.m_axi_bready),
        .s_axi_bresp   (master_if.m_axi_bresp),
        .s_axi_bvalid  (master_if.m_axi_bvalid),

        .s_axi_rdata   (master_if.m_axi_rdata),
        .s_axi_rlast   (master_if.m_axi_rlast),
        .s_axi_rready  (master_if.m_axi_rready),
        .s_axi_rresp   (master_if.m_axi_rresp),
        .s_axi_rvalid  (master_if.m_axi_rvalid),

        .s_axi_wdata   (master_if.m_axi_wdata),
        .s_axi_wlast   (master_if.m_axi_wlast),
        .s_axi_wready  (master_if.m_axi_wready),
        .s_axi_wstrb   (master_if.m_axi_wstrb),
        .s_axi_wvalid  (master_if.m_axi_wvalid),

        // BRAM 接口
        .bram_rst_a    (bram_rst_a),
        .bram_clk_a    (bram_clk_a),
        .bram_en_a     (bram_en_a),
        .bram_we_a     (bram_we_a),
        .bram_addr_a   (bram_addr_a),
        .bram_wrdata_a (bram_wrdata_a),
        .bram_rddata_a (bram_rddata_a),

        .bram_rst_b    (bram_rst_b),
        .bram_clk_b    (bram_clk_b),
        .bram_en_b     (bram_en_b),
        .bram_we_b     (bram_we_b),
        .bram_addr_b   (bram_addr_b),
        .bram_wrdata_b (bram_wrdata_b),
        .bram_rddata_b (bram_rddata_b)
    );

    // =========================================================================
    // BRAM 存储模块
    // =========================================================================
    blk_mem_gen_0 u_blk_mem (
        .clka       (bram_clk_a),
        .rsta       (bram_rst_a),
        .ena        (bram_en_a),
        .wea        (bram_we_a),
        .addra      (bram_addr_a),
        .dina       (bram_wrdata_a),
        .douta      (bram_rddata_a),

        .clkb       (bram_clk_b),
        .rstb       (bram_rst_b),
        .enb        (bram_en_b),
        .web        (bram_we_b),
        .addrb      (bram_addr_b),
        .dinb       (bram_wrdata_b),
        .doutb      (bram_rddata_b)
    );

endmodule
