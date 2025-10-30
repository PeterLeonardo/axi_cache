module cache_waysel #(
    parameter WAY_NUM_LOG2 = 2 // 例如 2 -> 4 路缓存
)(
    input  logic                    clk,
    input  logic                    rst,

    input  logic                    cache_hit,
    input  logic [WAY_NUM_LOG2-1:0] way_hit,
    output logic [WAY_NUM_LOG2-1:0] way_sel
);

    // 将 way_hit 扩展一位，最高位补 0，避免某些层索引为负宽度
    logic [WAY_NUM_LOG2:0] way_hit_0;
    always_comb begin
        way_hit_0 = {1'b0, way_hit};
    end

    // 生成树状历史位寄存结构（每层宽度不同）
    genvar way_index;
    generate
        for (way_index = 0; way_index < WAY_NUM_LOG2; way_index = way_index + 1) begin : invite_history
            // 本层历史位数：2^(剩余层数)
            localparam int GET_BITNUM = 1 << (WAY_NUM_LOG2 - way_index - 1);
            logic [GET_BITNUM-1:0] his_bit;

            // 更新历史位：在 cache 命中时，沿访问路径记录方向位
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    his_bit <= '0;
                end
                else if (cache_hit) begin
                    // 索引选择使用的是编译期常量范围（因为 way_index 是 genvar）
                    his_bit[ way_hit_0[WAY_NUM_LOG2 : way_index+1] ] <= way_hit_0[way_index];
                end
            end
        end
    endgenerate

    // ---------------------------------------------------------
    // 将 way_sel 的每一位用 generate+assign 生成（编译期展开）
    // 最高位（根节点）：
    // ---------------------------------------------------------
    // 根节点索引总是 0（只有一个 his_bit 元素）
    assign way_sel[WAY_NUM_LOG2-1] = ~invite_history[WAY_NUM_LOG2-1].his_bit[0];

    // ---------------------------------------------------------
    // 其余位：只有当 WAY_NUM_LOG2 > 1 时才需要生成
    // 使用 generate-for (genvar j) 在编译期展开，避免运行时循环
    // ---------------------------------------------------------
    generate
        if (WAY_NUM_LOG2 > 1) begin : gen_way_sel_lower
            genvar j;
            for (j = 0; j <= WAY_NUM_LOG2-2; j = j + 1) begin : gen_sel_bits
                // 计算当前位需要用到的上界/下界（编译期常量）
                localparam int IDX_HIGH = WAY_NUM_LOG2 - 1;
                localparam int IDX_LOW  = j + 1; // 注意：下界 >= 上界
                // 生成对应的位选择逻辑（连续赋值）
                assign way_sel[j] = ~invite_history[j].his_bit[ way_sel[IDX_HIGH : IDX_LOW] ];
            end
        end
    endgenerate

endmodule
