module cache_ctrl #(
    parameter READ_WORDS    =   4,
    parameter LFSR_INIT     =   8'hAD,

    parameter TAG_BITS      =   14,     // TAG位宽
    parameter INDEX_BITS    =   12,     // 缓存深度，必须为2**INDEX_BITS
    parameter OFFSET_BITS   =   4,      // OFFSET位宽
    parameter WAY_NUM       =   4       // 表示缓存共多少路
)(
    input  logic                clk,
    input  logic                rst,

    input  logic                re,
    input  logic [3:0]          we,
    input  logic [31:0]         addr,
    input  logic [31:0]         din,
    output logic [32*READ_WORDS-1:0]    dout,

    output logic                done,
    output logic                rvalid,
    output logic                error,
    input  logic                restart,
    output logic                busy
);

typedef enum logic [2:0] {
    IDLE        = 3'b000,
    COMPARE     = 3'b001,
    WRITE_BACK  = 3'b011,
    ALLOCATE    = 3'b100,
    REREAD      = 3'b110,
    RECOMPARE   = 3'b111,
    ERROR       = 3'b010;
} cache_state_t;

cache_state_t curr_state;
cache_state_t next_state;

logic           start;
logic           hit;
logic           row_diff;

logic [31:0]    addr_ahead;
logic [31:0]    addr_buff;
logic [31:0]    addr_ahead_buff;
logic [31:0]    din_buff;
logic           re_buff;
logic           we_buff;

logic           re_buff_buff;
logic           we_buff_buff;

always_comb begin
    start = re | we;
    row_diff = addr_ahead_buff[OFFSET+2] ^ addr_buff[OFFSET+2]; //不在同一行，需要重新读
    addr_ahead = addr - READ_WORDS*4;
end

always_ff @(posedge clk or posedge rst) begin
    if(rst) begin
        addr_buff   <= 32'b0;
        addr_ahead_buff <= 32'b0;
        din_buff    <= 32'b0;
        re_buff     <= 1'b0;
        we_buff     <= 1'b0;
    end
    else if(start && ~busy) begin
        addr_buff   <= addr;
        addr_ahead_buff <= addr_ahead;
        din_buff    <= din;
        re_buff     <= re;
        we_buff     <= we;
    end
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) curr_state <= IDLE;
    else curr_state <= next_state;
end

always_comb begin
    case(currState)
        IDLE: begin
            if(start) begin
                next_state = COMPARE;
            end
            else begin
                next_state = IDLE;
            end
        end
        COMPARE: begin
            if(hit) begin
                if(row_diff) begin next_state = REREAD; end
                else if(start) begin next_state = COMPARE;  end
            end
            else begin
                if(dirty) begin next_state = WRITE_BACK; end
                else begin next_state = ALLOCATE; end
            end
        end
        WRITE_BACK: begin
            if(axi_error) begin next_state = ERROR; end
            else if(axi_done) begin next_state = ALLOCATE; end
            else begin next_state = WRITE_BACK; end
        end
        ALLOCATE: begin
            if(axi_error) begin next_state = ERROR; end
            else if(axi_done) begin next_state = RECOMPARE; end
            else begin next_state = ALLOCATE; end
        end
        RECOMPARE: begin
            if(hit) begin
                if(row_diff_buff) begin next_state = REREAD; end
                else if(start) begin next_state = COMPARE; end
                else begin next_state = IDLE; end
            end
            else begin
                next_state = ERROR;
            end
        end
        REREAD: begin
            if(hit) begin
                if(start) begin
                    next_state = COMPARE;
                end
                else begin
                    next_state = IDLE;
                end
            end
            else begin
                if(dirty) begin next_state = WRITE_BACK; end
                else begin next_state = ALLOCATE; end
            end
        end
        ERROR: begin
            if(restart) begin next_state = IDLE; end
            else begin next_state = ERROR; end
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule