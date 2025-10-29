module cache_waysel #(
    parameter WAY_NUM_LOG2       =   2 //4路缓存
)(
    input  logic                    clk,
    input  logic                    rst,

    input  logic                    cache_hit,
    input  logic [WAY_NUM_LOG2-1:0] way_hit,
    output logic [WAY_NUM_LOG2-1:0] way_sel
);

logic [WAY_NUM_LOG2:0]  way_hit_0;

always_comb begin
    way_hit_0 = {1'b0, way_hit};
end

genvar way_index;
generate
    for(way_index = 0; way_index < WAY_NUM_LOG2; way_index = way_index+1) begin : invite_history
        int get_bitnum = 1<<(WAY_NUM_LOG2-way_index-1)
        logic [get_bitnum-1:0] his_bit;
        always_ff @( posedge clk or posedge rst ) begin
            if(rst) begin
                his_bit <= {get_bitnum{1'b0}};
            end
            else if (cache_hit) begin
                his_bit[way_hit_0[WAY_NUM_LOG2:way_index+1]] <= way_hit_0[way_index];
            end
        end
    end
endgenerate

integer i;
always_comb begin
    way_sel[WAY_NUM_LOG2-1] = ~(invite_history[WAY_NUM_LOG2-1].his_bit[0]);

`if WAY_NUM_LOG2>1
    for(i = WAY_NUM_LOG2-1; i>=0; i=i-1) begin
        way_sel[i] = ~(invite_history[i].his_bit[way_sel[WAY_NUM_LOG2-1:i+1]]);
    end
`endif

end

endmodule
