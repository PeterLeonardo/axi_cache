// AXI Master 接口
interface axi_master_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 1,    // 从信号列表看可能没有显式ID信号
    parameter REGION_WIDTH = 4
)(
    input logic aclk,
    input logic aresetn
);
    
    // ---------------------------
    // 读地�??通道
    // ---------------------------
    logic [ADDR_WIDTH-1:0]   m_axi_araddr;
    logic [1:0]              m_axi_arburst;
    logic [3:0]              m_axi_arcache;
    logic [7:0]              m_axi_arlen;
    logic [0:0]              m_axi_arlock;
    logic [2:0]              m_axi_arprot;
    logic [3:0]              m_axi_arqos;     // 修正: argos -> arqos
    logic                    m_axi_arready;
    logic [REGION_WIDTH-1:0] m_axi_arregion;
    logic [2:0]              m_axi_arsize;
    logic                    m_axi_arvalid;

    // ---------------------------
    // 写地�??通道  
    // ---------------------------
    logic [ADDR_WIDTH-1:0]   m_axi_awaddr;
    logic [1:0]              m_axi_awburst;
    logic [3:0]              m_axi_awcache;
    logic [7:0]              m_axi_awlen;
    logic [0:0]              m_axi_awlock;
    logic [2:0]              m_axi_awprot;
    logic [3:0]              m_axi_awqos;     // 修正: awgos -> awqos
    logic                    m_axi_awready;
    logic [REGION_WIDTH-1:0] m_axi_awregion;
    logic [2:0]              m_axi_awsize;
    logic                    m_axi_awvalid;

    // ---------------------------
    // 写响应�?�道
    // ---------------------------
    logic                    m_axi_bready;
    logic [1:0]              m_axi_bresp;
    logic                    m_axi_bvalid;

    // ---------------------------
    // 读数据�?�道
    // ---------------------------
    logic [DATA_WIDTH-1:0]   m_axi_rdata;
    logic                    m_axi_rlast;     // 修正: riast -> rlast
    logic                    m_axi_rready;
    logic [1:0]              m_axi_rresp;
    logic                    m_axi_rvalid;    // 修正: ryalid -> rvalid

    // ---------------------------
    // 写数据�?�道
    // ---------------------------
    logic [DATA_WIDTH-1:0]   m_axi_wdata;
    logic                    m_axi_wlast;
    logic                    m_axi_wready;
    logic [(DATA_WIDTH/8)-1:0] m_axi_wstrb;  // 注意: 图中没有但必�??的信�??
    logic                    m_axi_wvalid;

    // Master modport - 从主设备视角
    modport master (
        // 全局
        input  aclk,
        input  aresetn,
        
        // 读地�??通道
        output m_axi_araddr,
        output m_axi_arburst,
        output m_axi_arcache,
        output m_axi_arlen,
        output m_axi_arlock,
        output m_axi_arprot,
        output m_axi_arqos,
        input  m_axi_arready,
        output m_axi_arregion,
        output m_axi_arsize,
        output m_axi_arvalid,
        
        // 写地�??通道
        output m_axi_awaddr,
        output m_axi_awburst,
        output m_axi_awcache,
        output m_axi_awlen,
        output m_axi_awlock,
        output m_axi_awprot,
        output m_axi_awqos,
        input  m_axi_awready,
        output m_axi_awregion,
        output m_axi_awsize,
        output m_axi_awvalid,
        
        // 写响应�?�道
        output m_axi_bready,
        input  m_axi_bresp,
        input  m_axi_bvalid,
        
        // 读数据�?�道
        input  m_axi_rdata,
        input  m_axi_rlast,
        output m_axi_rready,
        input  m_axi_rresp,
        input  m_axi_rvalid,
        
        // 写数据�?�道
        output m_axi_wdata,
        output m_axi_wlast,
        input  m_axi_wready,
        output m_axi_wstrb,   // 必需的字节使能信�??
        output m_axi_wvalid
    );

endinterface

// AXI Slave 接口
interface axi_slave_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 1,
    parameter REGION_WIDTH = 4
)(
    input logic aclk,
    input logic aresetn
);
    
    // ---------------------------
    // 读地�??通道
    // ---------------------------
    logic [ADDR_WIDTH-1:0]   s_axi_araddr;
    logic [1:0]              s_axi_arburst;
    logic [3:0]              s_axi_arcache;
    logic [7:0]              s_axi_arlen;
    logic [0:0]              s_axi_arlock;
    logic [2:0]              s_axi_arprot;
    logic [3:0]              s_axi_arqos;
    logic                    s_axi_arready;
    logic [REGION_WIDTH-1:0] s_axi_arregion;
    logic [2:0]              s_axi_arsize;
    logic                    s_axi_arvalid;

    // ---------------------------
    // 写地�??通道  
    // ---------------------------
    logic [ADDR_WIDTH-1:0]   s_axi_awaddr;
    logic [1:0]              s_axi_awburst;
    logic [3:0]              s_axi_awcache;
    logic [7:0]              s_axi_awlen;
    logic [0:0]              s_axi_awlock;
    logic [2:0]              s_axi_awprot;
    logic [3:0]              s_axi_awqos;
    logic                    s_axi_awready;
    logic [REGION_WIDTH-1:0] s_axi_awregion;
    logic [2:0]              s_axi_awsize;
    logic                    s_axi_awvalid;

    // ---------------------------
    // 写响应�?�道
    // ---------------------------
    logic                    s_axi_bready;
    logic [1:0]              s_axi_bresp;
    logic                    s_axi_bvalid;

    // ---------------------------
    // 读数据�?�道
    // ---------------------------
    logic [DATA_WIDTH-1:0]   s_axi_rdata;
    logic                    s_axi_rlast;
    logic                    s_axi_rready;
    logic [1:0]              s_axi_rresp;
    logic                    s_axi_rvalid;

    // ---------------------------
    // 写数据�?�道
    // ---------------------------
    logic [DATA_WIDTH-1:0]   s_axi_wdata;
    logic                    s_axi_wlast;
    logic                    s_axi_wready;
    logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb;
    logic                    s_axi_wvalid;

    // Slave modport - 从从设备视角
    modport slave (
        // 全局
        input  aclk,
        input  aresetn,
        
        // 读地�??通道
        input  s_axi_araddr,
        input  s_axi_arburst,
        input  s_axi_arcache,
        input  s_axi_arlen,
        input  s_axi_arlock,
        input  s_axi_arprot,
        input  s_axi_arqos,
        output s_axi_arready,
        input  s_axi_arregion,
        input  s_axi_arsize,
        input  s_axi_arvalid,
        
        // 写地�??通道
        input  s_axi_awaddr,
        input  s_axi_awburst,
        input  s_axi_awcache,
        input  s_axi_awlen,
        input  s_axi_awlock,
        input  s_axi_awprot,
        input  s_axi_awqos,
        output s_axi_awready,
        input  s_axi_awregion,
        input  s_axi_awsize,
        input  s_axi_awvalid,
        
        // 写响应�?�道
        input  s_axi_bready,
        output s_axi_bresp,
        output s_axi_bvalid,
        
        // 读数据�?�道
        output s_axi_rdata,
        output s_axi_rlast,
        input  s_axi_rready,
        output s_axi_rresp,
        output s_axi_rvalid,
        
        // 写数据�?�道
        input  s_axi_wdata,
        input  s_axi_wlast,
        output s_axi_wready,
        input  s_axi_wstrb,
        input  s_axi_wvalid
    );

endinterface