// AXI Master 到 Slave 连接适配器模块
module axi_interconnect (
    axi_master_if.master master,
    axi_slave_if.slave   slave
);
    
    // =========================================================================
    // 写地址通道连接
    // =========================================================================
    assign slave.s_axi_awaddr   = master.m_axi_awaddr;
    assign slave.s_axi_awburst  = master.m_axi_awburst;
    assign slave.s_axi_awcache  = master.m_axi_awcache;
    assign slave.s_axi_awlen    = master.m_axi_awlen;
    assign slave.s_axi_awlock   = master.m_axi_awlock;
    assign slave.s_axi_awprot   = master.m_axi_awprot;
    assign slave.s_axi_awqos    = master.m_axi_awqos;
    assign slave.s_axi_awregion = master.m_axi_awregion;
    assign slave.s_axi_awsize   = master.m_axi_awsize;
    assign slave.s_axi_awvalid  = master.m_axi_awvalid;
    assign master.m_axi_awready = slave.s_axi_awready;

    // =========================================================================
    // 写数据通道连接
    // =========================================================================
    assign slave.s_axi_wdata    = master.m_axi_wdata;
    assign slave.s_axi_wlast    = master.m_axi_wlast;
    assign slave.s_axi_wstrb    = master.m_axi_wstrb;
    assign slave.s_axi_wvalid   = master.m_axi_wvalid;
    assign master.m_axi_wready  = slave.s_axi_wready;

    // =========================================================================
    // 写响应通道连接
    // =========================================================================
    assign master.m_axi_bresp   = slave.s_axi_bresp;
    assign master.m_axi_bvalid  = slave.s_axi_bvalid;
    assign slave.s_axi_bready   = master.m_axi_bready;

    // =========================================================================
    // 读地址通道连接
    // =========================================================================
    assign slave.s_axi_araddr   = master.m_axi_araddr;
    assign slave.s_axi_arburst  = master.m_axi_arburst;
    assign slave.s_axi_arcache  = master.m_axi_arcache;
    assign slave.s_axi_arlen    = master.m_axi_arlen;
    assign slave.s_axi_arlock   = master.m_axi_arlock;
    assign slave.s_axi_arprot   = master.m_axi_arprot;
    assign slave.s_axi_arqos    = master.m_axi_arqos;
    assign slave.s_axi_arregion = master.m_axi_arregion;
    assign slave.s_axi_arsize   = master.m_axi_arsize;
    assign slave.s_axi_arvalid  = master.m_axi_arvalid;
    assign master.m_axi_arready = slave.s_axi_arready;

    // =========================================================================
    // 读数据通道连接
    // =========================================================================
    assign master.m_axi_rdata   = slave.s_axi_rdata;
    assign master.m_axi_rlast    = slave.s_axi_rlast;
    assign master.m_axi_rresp    = slave.s_axi_rresp;
    assign master.m_axi_rvalid   = slave.s_axi_rvalid;
    assign slave.s_axi_rready    = master.m_axi_rready;

endmodule