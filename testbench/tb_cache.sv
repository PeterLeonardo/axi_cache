`timescale 1ns/1ps

module tb_cache;

    // ==========================================================
    // 参数定义（与 DUT 对应）
    // ==========================================================
    localparam READ_WORDS       = 4;
    localparam TAG_BITS         = 14;
    localparam INDEX_BITS       = 12;
    localparam OFFSET_BITS      = 4;
    localparam WAY_NUM          = 4;
    localparam ADDR_WIDTH       = 32;
    localparam DATA_WIDTH       = 32;
    localparam BURST_LEN_WIDTH  = 8;
    localparam MAX_BURST_LEN    = 16;
    localparam ID_WIDTH         = 4;
    localparam REGION_WIDTH     = 4;

    // ==========================================================
    // DUT 接口信号
    // ==========================================================
    logic                    clk;
    logic                    rst;

    logic                    re;
    logic [3:0]              we;
    logic [ADDR_WIDTH-1:0]   addr;
    logic [DATA_WIDTH-1:0]   din;
    logic [DATA_WIDTH*READ_WORDS-1:0] dout;
    logic                    done;
    logic                    rvalid;
    logic                    error;
    logic                    restart;
    logic                    busy;

    // ==========================================================
    // DUT 实例化
    // ==========================================================
    cache_example #(
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
    ) cache_example_inst (
        .clk(clk),
        .rst(rst),

        .re(re),
        .we(we),
        .addr(addr),
        .din(din),
        .dout(dout),
        .done(done),
        .rvalid(rvalid),
        .error(error),
        .restart(restart),
        .busy(busy)
    );

    // ==========================================================
    // 时钟与复位
    // ==========================================================
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz 时钟

    initial begin
        rst = 1;
        restart = 0;
        re = 0;
        we = 4'b0;
        addr = 0;
        din = 0;
        repeat(1) @(posedge clk);
        rst = 0;
    end

    // ==========================================================
    // 文件驱动测试 task
    // ==========================================================
    task automatic run_test(input string infile, input string outfile);
        integer fin, fout;
        integer rv;
        reg [7:0]  re_i;
        reg [3:0]  we_i;
        reg [31:0] addr_i, din_i;

        begin
            // 打开输入文件
            fin  = $fopen(infile, "r");
            if (fin == 0) begin
                $display("ERROR: 无法打开输入文件 %s", infile);
                $finish;
            end

            // 打开输出文件
            fout = $fopen(outfile, "w");
            if (fout == 0) begin
                $display("ERROR: 无法创建输出文件 %s", outfile);
                $finish;
            end

            // 等待复位完成
            @(negedge rst);
            $display(">>> 开始测试：%s -> %s <<<", infile, outfile);

            forever begin
                @(posedge clk);

                // 当 cache 不忙时，从文件读一行
                if (!busy) begin
                    if (!$feof(fin)) begin
                        rv = $fscanf(fin, "%d %b %h %h\n", re_i, we_i, addr_i, din_i);
                        $display("%d %b %h %h\n", re_i, we_i, addr_i, din_i);
                        if (rv == 4) begin
                            re   <= re_i;
                            we   <= we_i;
                            addr <= addr_i;
                            din  <= din_i;
                        end else begin
                            re   <= 0;
                            we   <= 0;
                        end
                    end else begin
                        addr <= addr;
                        din <= din;
                        re <= 0;
                        we <= 0;
                        $finish;
                    end
                end
                // 当 done=1 时写出结果
                if (done) begin
                    $fdisplay(fout, "%h %0d", dout, rvalid);
                end
            end
        end
    endtask

    // ==========================================================
    // 主测试入口
    // ==========================================================
    initial begin
        $display(">>> 仿真开始 <<<\n");
        run_test("../../../../../files/input.txt", "../../../../../data/output.txt");
    end

    // ==========================================================
    // 仿真超时保护
    // ==========================================================
    initial begin
        #200000000;
        $display(">>> 仿真超时结束 <<<");
        $finish;
    end

endmodule
