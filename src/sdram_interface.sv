module sdram_interface(
    input clk,
    input reset_n,


    //fifo interface
    input fifo_line_fill_req,
    input [7:0] fifo_burst_len,
    input [9:0] fifo_line_to_fill,
    input [7:0] x_scroll,
    output fifo_line_fill_ack,
    output logic fifo_write_en,
    output logic [31:0] fifo_sdram_data_out,

    //cpu interface
    input [20:0] cpu_addr,
    input [15:0] cpu_sdram_data_in,
    input cpu_cs,
    input rd_raw,
    input cpu_uw,
    input cpu_lw,
    output [15:0] cpu_data_out,
    output cpu_dtack,

    //control register stuff
    output logic controlRegWr,
    output logic controlRegRd,
    input logic [7:0] creg_data_in,
    input creg_busy,
    //blitter interface
    
    output logic blitter_fifo_wr,
    input blitter_fifo_fill_req,
    input [9:0] blitter_line,
    input [7:0] blitterXoffset,
    input [31:0] blitter_data_in,
    output logic blitter_fifo_rd_en,
    input blitter_fifo_commit_req,
    output blitter_ack,
    input blitReady,

    //sdram interface
    output O_sdram_clk,
	output O_sdram_cke,
	output O_sdram_cs_n,
	output O_sdram_cas_n,
	output O_sdram_ras_n,
	output O_sdram_wen_n,
	output [3:0] O_sdram_dqm,
	output [10:0] O_sdram_addr,
	output [1:0] O_sdram_ba,
	inout [31:0] IO_sdram_dq
); 

assign cpu_data_out = (sdram_cs) ? cpu_sdram_data_out : creg_sdram_data_out;
logic [15:0] creg_sdram_data_out;
logic [15:0] cpu_sdram_data_out;

logic sdram_dtack;
logic creg_dtack;
assign cpu_dtack = (sdram_dtack|creg_dtack);

// SDRAM command definitions
localparam logic [2:0] NOP_CMD = 3'b111;
localparam logic [2:0] ACT_CMD = 3'b011;
localparam logic [2:0] READ_CMD = 3'b101;
localparam logic [2:0] WRITE_CMD = 3'b100;
localparam logic [2:0] PRECH_CMD = 3'b010;
localparam logic [2:0] REFRESH_CMD=  3'b001;

// timing related
localparam logic [2:0] READ_DELAY = 7;
localparam logic [22:0] REFRESH_CYCLES = 80_000;
localparam logic [3:0] DTACK_HOLD = 6;
logic [3:0] dtackHold;
//CDC sync
logic [1:0] line_fill_req_sync;
always @(posedge clk) begin 
    line_fill_req_sync <= {line_fill_req_sync[0],fifo_line_fill_req};
end
logic cpu_rd;
reg [15:0] lastData;
reg reset_n_sync;
reg cs1,cs2,cs3,cs4,cs5,cs6,rd1,rd2;
always @(posedge clk) begin 
  
    rd1 <= rd_raw;
    rd2 <= rd1;
    cpu_rd <= rd2;
    
    reset_n_sync <= reset_n;

end

//sdram clock

logic burst_ack;
assign blitter_ack = (req_source == SRC_BLITTER) ? burst_ack : 1'b0;
assign fifo_line_fill_ack = (req_source == SRC_VIDEO) ? burst_ack : 1'b0;

wire actual_request = (req_source == SRC_BLITTER)? blitter_fifo_fill_req :
                      (req_source == SRC_VIDEO) ? line_fill_req_sync[1] : 1'b0;


logic [20:0] I_sdrc_addr;
logic [31:0] I_sdrc_data;
logic [3:0] I_sdrc_dqm;
logic [7:0] I_sdrc_data_len;
logic [2:0] I_sdrc_cmd;
logic I_sdrc_cmd_en;

wire [31:0] O_sdrc_data;
wire O_sdrc_init_done;
wire O_sdrc_cmd_ack;

SDRAM_Controller_HS_Top sdrc2(
	.O_sdram_clk, //output O_sdram_clk
	.O_sdram_cke, //output O_sdram_cke
	.O_sdram_cs_n, //output O_sdram_cs_n
	.O_sdram_cas_n, //output O_sdram_cas_n
	.O_sdram_ras_n, //output O_sdram_ras_n
	.O_sdram_wen_n, //output O_sdram_wen_n
	.O_sdram_dqm, //output [3:0] O_sdram_dqm
	.O_sdram_addr, //output [10:0] O_sdram_addr
	.O_sdram_ba, //output [1:0] O_sdram_ba
	.IO_sdram_dq, //inout [31:0] IO_sdram_dq

	.I_sdrc_rst_n(reset_n_sync), //input I_sdrc_rst_n
	.I_sdrc_clk(clk), //input I_sdrc_clk
	.I_sdram_clk(clk), //input I_sdram_clk
	.I_sdrc_cmd_en, //input I_sdrc_cmd_en
	.I_sdrc_cmd, //input [2:0] I_sdrc_cmd
	.I_sdrc_precharge_ctrl(1), //input I_sdrc_precharge_ctrl
	.I_sdram_power_down(0), //input I_sdram_power_down
	.I_sdram_selfrefresh(0), //input I_sdram_selfrefresh
	.I_sdrc_addr, //input [20:0] I_sdrc_addr
	.I_sdrc_dqm, //input [3:0] I_sdrc_dqm
	.I_sdrc_data, //input [31:0] I_sdrc_data
	.I_sdrc_data_len, //input [7:0] I_sdrc_data_len
	.O_sdrc_data, //output [31:0] O_sdrc_data
	.O_sdrc_init_done, //output O_sdrc_init_done
	.O_sdrc_cmd_ack //output O_sdrc_cmd_ack
);



wire sdram_cs = cpu_cs & ~cpu_addr[20] & ~creg_dtack;
wire reg_cs = cpu_cs & cpu_addr[20] & ~sdram_dtack;
typedef enum logic [3:0] {
    CREG_IDLE,
    CREG_START,
    CREG_DTACK
} creg_fsm_state_t;
creg_fsm_state_t creg_state;
always @(posedge clk) begin 
    controlRegWr <= 0;
    controlRegRd <= 0;
    creg_dtack <=0;
    if(~reset_n_sync) begin 
        creg_state <= CREG_IDLE;
    end else 
    case (creg_state) 
        CREG_IDLE: begin 
            if(reg_cs && ~creg_busy) begin 
                 creg_state <= CREG_START;
            end
        end
        CREG_START: begin 
            if (cpu_rd) begin 
                controlRegRd <= 1;
                controlRegWr <= 0;
            end else begin 
                controlRegWr <= 1;
                controlRegRd <= 0;
            end 
            creg_state <= CREG_DTACK;

        end
        CREG_DTACK: begin 
            creg_sdram_data_out <= blitReady;
            creg_dtack <= 1;
            if (~cpu_cs) begin 
                creg_state <= CREG_IDLE;
            end
        end
    endcase
end

typedef enum logic [4:0] {
    STARTUP, //0
    IDLE, //1
    CS_DELAY, //2
    ACTIVATE,// 3
    READ,//4
    WRITE,//5
    DTACK,//6
    REFRESH,//7
    ACTIVATE_LINE_FILL,//8
    READ_LINE_FILL, //9
    END_LINE_FILL, //a

    BLITTER_ACTIVATE,//c
    BLITTER_LINE_FILL,//d
    BLITTER_LINE_COMMIT,//e
    BLITTER_LINE_COMMIT_ACK,
    BLITTER_OPERATION_DONE//f
} sdram_state_t;

sdram_state_t sdram_fsm_state;

typedef enum logic [3:0] {
    SRC_NONE,
    SRC_VIDEO,
    SRC_BLITTER
} line_fill_req_src_t;

line_fill_req_src_t req_source;

logic sdrc_busy;
logic [4:0] readDelay;
logic [7:0] cregDelay;
logic [22:0] refreshCounter; 
logic [7:0] burstLen;
logic firstWord;
always @(posedge clk) begin
    fifo_write_en <= 0;
    blitter_fifo_wr <=0;
    sdram_dtack <=0;
    
    burst_ack <= 0;
blitter_fifo_rd_en <=0;

    if (~reset_n_sync) begin
        sdram_fsm_state <= STARTUP;
        refreshCounter <= REFRESH_CYCLES;
    end else begin  
        case (sdram_fsm_state)
            
            STARTUP: begin 
                if (O_sdrc_init_done) sdram_fsm_state <= IDLE;
            end

            IDLE: begin 
                req_source <= SRC_NONE;
                I_sdrc_data_len <= 0;
                refreshCounter <= refreshCounter - 23'd1;
                if (line_fill_req_sync[1]) begin
                    req_source <= SRC_VIDEO;
                    I_sdrc_data_len <= fifo_burst_len;
                    I_sdrc_addr <= {2'b00,1'b0,fifo_line_to_fill,x_scroll};
                    I_sdrc_cmd <= ACT_CMD;
                    I_sdrc_cmd_en <= 1;
                    sdram_fsm_state <= ACTIVATE_LINE_FILL;
                end else begin
                    if (blitter_fifo_fill_req) begin 
                        req_source <= SRC_BLITTER;
                        I_sdrc_data_len <= 8'hff;
                        I_sdrc_addr <= {2'b00,1'b0,blitter_line,blitterXoffset};
                        I_sdrc_cmd <= ACT_CMD;
                        I_sdrc_cmd_en <= 1;
                        sdram_fsm_state <= ACTIVATE_LINE_FILL;
                    end else
                    if (blitter_fifo_commit_req) begin 
                        req_source <= SRC_BLITTER;

                        I_sdrc_data_len <= 8'hff;
                        I_sdrc_addr <= {2'b00,1'b0,blitter_line,8'd0};
                        I_sdrc_cmd <= ACT_CMD;
                        I_sdrc_cmd_en <= 1;
                        sdram_fsm_state <= BLITTER_ACTIVATE;
                        firstWord <=1;
                    end else begin
                        if(refreshCounter == 0) begin 
                            I_sdrc_cmd <= REFRESH_CMD;
                            I_sdrc_cmd_en <= 1;
                            sdram_fsm_state <= REFRESH;
                        end else begin
                            if (sdram_cs) begin 
                                sdram_fsm_state <= CS_DELAY;
                            end
                        end
                    end
                end
            end

            CS_DELAY: begin 
                    I_sdrc_addr <= cpu_addr[19:1];
                    I_sdrc_data <= {cpu_sdram_data_in[7:0],cpu_sdram_data_in[15:8],cpu_sdram_data_in[7:0],cpu_sdram_data_in[15:8]};
                    case({cpu_uw,cpu_lw,cpu_addr[0]})
                        3'b010: I_sdrc_dqm <= 4'b1101;
                        3'b011: I_sdrc_dqm <= 4'b0111;
                        3'b100: I_sdrc_dqm <= 4'b1110;
                        3'b101: I_sdrc_dqm <= 4'b1011;
                        3'b110: I_sdrc_dqm <= 4'b1100;
                        3'b111: I_sdrc_dqm <= 4'b0011;
                        default: I_sdrc_dqm <= 4'b0000;
                    endcase
                    I_sdrc_cmd <= ACT_CMD;
                    I_sdrc_cmd_en <= 1;
                    sdram_fsm_state <= ACTIVATE;
                    
            end

            ACTIVATE: begin 
                I_sdrc_cmd_en <=0;
                if (O_sdrc_cmd_ack) begin 
                    if (cpu_rd) begin 
                        I_sdrc_cmd <= READ_CMD;
                        I_sdrc_cmd_en <=1;
                        sdram_fsm_state <= READ;
                        readDelay <= READ_DELAY;
                    end else begin 
                        I_sdrc_cmd <= WRITE_CMD;
                        I_sdrc_cmd_en <= 1;
                        sdram_fsm_state <= WRITE;
                    end 
                end 
            end

            READ: begin 
                I_sdrc_cmd_en <=0;
                if (readDelay ==0) begin 
                    sdram_fsm_state <= DTACK;
                    if (cpu_addr[0]) cpu_sdram_data_out <= {O_sdrc_data[23:16],O_sdrc_data[31:24]}; //O_sdrc_data[31:16];
                    else cpu_sdram_data_out <= {O_sdrc_data[7:0],O_sdrc_data[15:8]};//O_sdrc_data[15:0];
                end else begin
                    readDelay <= readDelay -1;
                end
            end

            WRITE: begin 
                I_sdrc_cmd_en <=0;
                if(O_sdrc_cmd_ack) begin
                    sdram_fsm_state <= DTACK;
                end
            end

            DTACK: begin 
                sdram_dtack<=1;
                if (~cpu_cs)begin 
                    sdram_fsm_state <= IDLE;
                end
                    
            end

            REFRESH: begin 
                I_sdrc_cmd_en <=0;
                if(O_sdrc_cmd_ack) begin
                    sdram_fsm_state <= IDLE;
                    refreshCounter <= REFRESH_CYCLES;
                end 
            end

            ACTIVATE_LINE_FILL: begin 
                I_sdrc_cmd_en <= 0;
                if(O_sdrc_cmd_ack) begin 
                    I_sdrc_dqm <= 4'b0000;
                    readDelay <= READ_DELAY;
                    I_sdrc_cmd <= READ_CMD;
                    I_sdrc_cmd_en <=1;
                    sdram_fsm_state <= READ_LINE_FILL;
                    burstLen <= 0;
                end
            end
            READ_LINE_FILL: begin 
                I_sdrc_cmd_en <= 0;
                if ((readDelay) == 2) begin 
                    if(req_source == SRC_VIDEO) fifo_write_en <= 1;
                    if(req_source == SRC_BLITTER) blitter_fifo_wr <= 1;
                    fifo_sdram_data_out <= O_sdrc_data;
                    if (burstLen == I_sdrc_data_len) begin 
                        burstLen <= 0;
                        sdram_fsm_state <= END_LINE_FILL;
                    end else burstLen <= burstLen + 1;

                end else readDelay <= readDelay -1;

            end
            END_LINE_FILL: begin 
                burst_ack <= 1;
                if (~actual_request) begin 
                    burst_ack <=0;
                    sdram_fsm_state <= IDLE;
                end
            end
            BLITTER_ACTIVATE: begin 
                I_sdrc_cmd_en <= 0;
                blitter_fifo_rd_en <=1;

                if (firstWord) begin 
                    firstWord <= 0;
                    blitter_fifo_rd_en <=0;
                end
                if(O_sdrc_cmd_ack) begin 
                    I_sdrc_dqm <= 4'b0000;
                    
                        I_sdrc_data <= blitter_data_in;

                        I_sdrc_cmd <= WRITE_CMD;
                        I_sdrc_cmd_en <= 1;
                        sdram_fsm_state <= BLITTER_LINE_COMMIT;
                        burstLen <= 0;
                  
                end
            end
            
            
            BLITTER_LINE_COMMIT: begin 
                I_sdrc_cmd_en <= 0;
                blitter_fifo_rd_en <=1;
                I_sdrc_data <= blitter_data_in;
                if (burstLen == I_sdrc_data_len) begin 
                    burstLen <= 0;
                    sdram_fsm_state <= BLITTER_LINE_COMMIT_ACK;
                end else burstLen <= burstLen + 1;

            end
            BLITTER_LINE_COMMIT_ACK: begin 
                if (O_sdrc_cmd_ack) begin 
                    sdram_fsm_state <= BLITTER_OPERATION_DONE;
                    burst_ack <=1; 
                end
            end
            BLITTER_OPERATION_DONE: begin 
                
                blitter_fifo_rd_en <= 0;
                if(~(blitter_fifo_commit_req | blitter_fifo_fill_req)) begin 
                    burst_ack <=0;
                    sdram_fsm_state <= IDLE;
                end
                
            end
        endcase

    end

end 

endmodule