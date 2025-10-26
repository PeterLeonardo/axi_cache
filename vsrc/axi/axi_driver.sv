// 可综合的 AXI Master 驱动模块
// 使用组合逻辑实现通道控制
module axi_master_driver #(
    parameter ADDR_WIDTH      = 32,        // 地址宽度
    parameter DATA_WIDTH      = 32,        // 数据宽度  
    parameter BURST_LEN_WIDTH = 8,         // 突发长度宽度
    parameter MAX_BURST_LEN   = 16,        // 最大突发长度
    parameter ID_WIDTH        = 1,
    parameter REGION_WIDTH    = 4
)(
    // AXI Master 接口
    axi_master_if.master axi_bus,
    
    // 用户控制接口
    input  logic                            start_i,          // 启动事务
    input  logic                            wr_rd_i,          // 0=读, 1=写
    input  logic [DATA_WIDTH/8-1:0]         wr_wstrb_i,       // wstrb e.g. 4'b1111
    input  logic [ADDR_WIDTH-1:0]           addr_i,           // 起始地址
    input  logic [BURST_LEN_WIDTH-1:0]      len_i,            // 突发长度 (实际长度 = len_i + 1)
    input  logic [2:0]                      size_i,           // 传输大小 (字节数 = 2^size_i)
    input  logic [1:0]                      burst_i,          // 突发类型
    input  logic [DATA_WIDTH-1:0]           data_i,           // 单数据输入
    input  logic [DATA_WIDTH-1:0]           data_array_i [MAX_BURST_LEN], // 数据数组输入
    input  logic                            use_array_i,      // 使用数据数组模式
    
    // 状态输出
    output logic                            done_o,           // 事务完成
    output logic [DATA_WIDTH-1:0]           data_o,           // 读取数据
    output logic                            data_valid_o,     // 读数据有效
    output logic [1:0]                      resp_o,           // 响应状态
    output logic                            error_o,          // 错误指示
    output logic                            busy_o            // 驱动忙状态
);

    // =========================================================================
    // 状态机定义
    // =========================================================================
    typedef enum logic [2:0] {
        ST_IDLE       = 3'b000,  // 空闲状态
        ST_WR_ADDR    = 3'b001,  // 写地址阶段
        ST_WR_DATA    = 3'b010,  // 写数据阶段  
        ST_WR_RESP    = 3'b011,  // 写响应阶段
        ST_RD_ADDR    = 3'b100,  // 读地址阶段
        ST_RD_DATA    = 3'b101   // 读数据阶段
    } state_t;

    // 状态寄存器
    state_t current_state;
    state_t next_state;
    
    // =========================================================================
    // 内部寄存器和信号
    // =========================================================================
    logic [ADDR_WIDTH-1:0]      current_addr;       // 当前传输地址
    logic [BURST_LEN_WIDTH-1:0] beat_counter;       // 当前传输计数
    logic [BURST_LEN_WIDTH-1:0] total_beats;        // 总传输次数
    logic                       is_write;           // 当前事务类型
    logic [DATA_WIDTH-1:0]      data_buffer [MAX_BURST_LEN]; // 数据缓冲区
    logic [DATA_WIDTH-1:0]      singledata_buffer;  // 单数据缓冲区
    logic [DATA_WIDTH/8-1:0]    wstrb_buffer;       // 字节使能缓冲区
    logic                       use_array_buf;      // 使用数组模式缓冲区
    
    logic [7:0]                 size_power;         // 2 ** size_i

    // 计算 2 ** size_i
    assign size_power = 8'b1 << size_i;

    // =========================================================================
    // 状态寄存器
    // =========================================================================
    always_ff @(posedge axi_bus.aclk or negedge axi_bus.aresetn) begin
        if (!axi_bus.aresetn) begin
            current_state <= ST_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // =========================================================================
    // 下一状态逻辑 - 组合逻辑
    // =========================================================================
    always_comb begin
        next_state = current_state;
        
        unique case (current_state)
            ST_IDLE: begin
                if (start_i && !busy_o) begin
                    if (wr_rd_i) begin
                        next_state = ST_WR_ADDR;
                    end else begin
                        next_state = ST_RD_ADDR;
                    end
                end
            end
            
            ST_WR_ADDR: begin
                if (axi_bus.m_axi_awvalid && axi_bus.m_axi_awready) begin
                    next_state = ST_WR_DATA;
                end
            end
            
            ST_WR_DATA: begin
                if (axi_bus.m_axi_wvalid && axi_bus.m_axi_wready && axi_bus.m_axi_wlast) begin
                    next_state = ST_WR_RESP;
                end
            end
            
            ST_WR_RESP: begin
                if (axi_bus.m_axi_bvalid && axi_bus.m_axi_bready) begin
                    next_state = ST_IDLE;
                end
            end
            
            ST_RD_ADDR: begin
                if (axi_bus.m_axi_arvalid && axi_bus.m_axi_arready) begin
                    next_state = ST_RD_DATA;
                end
            end
            
            ST_RD_DATA: begin
                if (axi_bus.m_axi_rvalid && axi_bus.m_axi_rready && axi_bus.m_axi_rlast) begin
                    next_state = ST_IDLE;
                end
            end
            
            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    // =========================================================================
    // 地址和数据计数器 - 时序逻辑
    // =========================================================================
    always_ff @(posedge axi_bus.aclk or negedge axi_bus.aresetn) begin
        if (!axi_bus.aresetn) begin
            current_addr  <= '0;
            beat_counter  <= '0;
            total_beats   <= '0;
            is_write      <= 1'b0;
            busy_o        <= 1'b0;
            singledata_buffer <= '0;
            wstrb_buffer  <= '0;
            use_array_buf <= 1'b0;
            
            // 初始化数据缓冲区
            for (int i = 0; i < MAX_BURST_LEN; i++) begin
                data_buffer[i] <= '0;
            end
        end else begin
            unique case (current_state)
                ST_IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i && !busy_o) begin
                        // 捕获用户参数
                        current_addr <= addr_i;
                        total_beats  <= len_i;
                        beat_counter <= '0;
                        is_write     <= wr_rd_i;
                        busy_o       <= 1'b1;
                        
                        // 加载数据到缓冲区
                        if (wr_rd_i && use_array_i) begin
                            for (int i = 0; i <= len_i; i++) begin
                                if (i < MAX_BURST_LEN) begin
                                    data_buffer[i] <= data_array_i[i];
                                end
                            end
                            use_array_buf <= 1'b1;
                        end else if (wr_rd_i && ~use_array_i) begin
                            singledata_buffer <= data_i;
                            use_array_buf <= 1'b0;
                        end
                        wstrb_buffer <= wr_wstrb_i;
                    end
                end
                
                ST_WR_DATA: begin
                    if (axi_bus.m_axi_wvalid && axi_bus.m_axi_wready) begin
                        if (beat_counter == total_beats) begin
                            // 最后一个数据传输完成
                            beat_counter <= '0;
                        end else begin
                            // 递增计数器
                            beat_counter <= beat_counter + 1'b1;
                            
                            // 根据突发类型更新地址
                            case (burst_i)
                                2'b00: begin // FIXED - 地址不变
                                    // 保持当前地址
                                end
                                2'b01: begin // INCR - 地址递增
                                    current_addr <= current_addr + size_power;
                                end
                                2'b10: begin // WRAP - 地址回环
                                    current_addr <= current_addr + size_power;
                                end
                                default: begin
                                    current_addr <= current_addr + size_power;
                                end
                            endcase
                        end
                    end
                end
                
                ST_RD_DATA: begin
                    if (axi_bus.m_axi_rvalid && axi_bus.m_axi_rready) begin
                        if (axi_bus.m_axi_rlast) begin
                            beat_counter <= '0;
                        end else begin
                            beat_counter <= beat_counter + 1'b1;
                        end
                    end
                end
                
                default: begin
                    // 其他状态保持计数器不变
                end
            endcase
        end
    end

    // =========================================================================
    // AXI 写地址通道控制 - 组合逻辑
    // =========================================================================
    always_comb begin
        // 默认值
        axi_bus.m_axi_awvalid = 1'b0;
        axi_bus.m_axi_awaddr  = '0;
        axi_bus.m_axi_awlen   = '0;
        axi_bus.m_axi_awsize  = '0;
        axi_bus.m_axi_awburst = '0;
        axi_bus.m_axi_awlock  = 1'b0;
        axi_bus.m_axi_awcache = 4'b0011;
        axi_bus.m_axi_awprot  = 3'b010;
        axi_bus.m_axi_awqos   = 4'b0000;
        
        if (current_state == ST_WR_ADDR) begin
            axi_bus.m_axi_awvalid = 1'b1;
            axi_bus.m_axi_awaddr  = current_addr;
            axi_bus.m_axi_awlen   = total_beats;
            axi_bus.m_axi_awsize  = size_i;
            axi_bus.m_axi_awburst = burst_i;
        end
    end

    // =========================================================================
    // AXI 写数据通道控制 - 组合逻辑
    // =========================================================================
    always_comb begin
        // 默认值
        axi_bus.m_axi_wvalid = 1'b0;
        axi_bus.m_axi_wdata  = '0;
        axi_bus.m_axi_wlast  = 1'b0;
        axi_bus.m_axi_wstrb  = '0;
        
        if (current_state == ST_WR_DATA) begin
            axi_bus.m_axi_wvalid = 1'b1;
            
            // 选择数据源：数组模式或单数据模式
            if (use_array_buf) begin
                axi_bus.m_axi_wdata = data_buffer[beat_counter];
            end else begin
                axi_bus.m_axi_wdata = singledata_buffer;
            end
            
            axi_bus.m_axi_wlast = (beat_counter == total_beats);
            axi_bus.m_axi_wstrb = wstrb_buffer;
        end
    end

    // =========================================================================
    // AXI 写响应通道控制 - 组合逻辑
    // =========================================================================
    always_comb begin
        axi_bus.m_axi_bready = (current_state == ST_WR_RESP);
    end

    // =========================================================================
    // AXI 读地址通道控制 - 组合逻辑
    // =========================================================================
    always_comb begin
        // 默认值
        axi_bus.m_axi_arvalid = 1'b0;
        axi_bus.m_axi_araddr  = '0;
        axi_bus.m_axi_arlen   = '0;
        axi_bus.m_axi_arsize  = '0;
        axi_bus.m_axi_arburst = '0;
        axi_bus.m_axi_arlock  = 1'b0;
        axi_bus.m_axi_arcache = 4'b0011;
        axi_bus.m_axi_arprot  = 3'b010;
        axi_bus.m_axi_arqos   = 4'b0000;
        
        if (current_state == ST_RD_ADDR) begin
            axi_bus.m_axi_arvalid = 1'b1;
            axi_bus.m_axi_araddr  = current_addr;
            axi_bus.m_axi_arlen   = total_beats;
            axi_bus.m_axi_arsize  = size_i;
            axi_bus.m_axi_arburst = burst_i;
        end
    end

    // =========================================================================
    // AXI 读数据通道控制 - 组合逻辑
    // =========================================================================
    always_comb begin
        axi_bus.m_axi_rready = (current_state == ST_RD_DATA);
    end

    // =========================================================================
    // 读数据捕获 - 时序逻辑
    // =========================================================================
    always_ff @(posedge axi_bus.aclk or negedge axi_bus.aresetn) begin
        if (!axi_bus.aresetn) begin
            data_o <= '0;
            data_valid_o <= 1'b0;
        end else begin
            data_valid_o <= 1'b0;  // 默认低电平
            
            // 捕获读取的数据
            if (axi_bus.m_axi_rvalid && axi_bus.m_axi_rready) begin
                data_o <= axi_bus.m_axi_rdata;
                data_valid_o <= 1'b1;  // 只在有效数据时置高
            end
        end
    end

    // =========================================================================
    // 状态输出和错误处理 - 时序逻辑
    // =========================================================================
    always_ff @(posedge axi_bus.aclk or negedge axi_bus.aresetn) begin
        if (!axi_bus.aresetn) begin
            done_o  <= 1'b0;
            resp_o  <= 2'b00;
            error_o <= 1'b0;
        end else begin
            // 默认值
            done_o <= 1'b0;
            
            unique case (current_state)
                ST_WR_RESP: begin
                    if (axi_bus.m_axi_bvalid && axi_bus.m_axi_bready) begin
                        done_o  <= 1'b1;
                        resp_o  <= axi_bus.m_axi_bresp;
                        error_o <= (axi_bus.m_axi_bresp != 2'b00);
                    end
                end
                
                ST_RD_DATA: begin
                    if (axi_bus.m_axi_rvalid && axi_bus.m_axi_rready && axi_bus.m_axi_rlast) begin
                        done_o  <= 1'b1;
                        resp_o  <= axi_bus.m_axi_rresp;
                        error_o <= (axi_bus.m_axi_rresp != 2'b00);
                    end
                end
                
                default: begin
                    // 保持输出不变
                end
            endcase
        end
    end

endmodule