module blitter(
    input rst,
    input blit_clk,
    input sdram_clk,

    input [15:0] dest_x,
    input [15:0] dest_y,

    input [15:0] width,
    input [15:0] height,
    input [15:0] pattern [16],
    input [7:0] fillData,
    input [7:0] fillBgCol,
    input [7:0] blitterCmd,
    input [7:0] patternFillMode,
    input startBlit,
    output blitReady,

    input [31:0] data_in,
    input blitterWr,
    output reg fifoFillRequest,
    input fifoFillAck,
    output logic [9:0] blitter_line,
    output [31:0] data_out,
    input blitterFifoRdEn,
    output reg outputFifoCommitRequest,
    input outputFifoCommitAck
);


localparam logic [7:0] BLIT_CMD_FILL = 8'h00;

localparam logic [7:0] PATTERN_MODE_REPLACE = 8'h00;
localparam logic [7:0] PATTERN_MODE_XOR = 8'h01;
logic blitRequested;
always @(posedge blit_clk) begin 
    if(rst) blitRequested <= 0;
    else begin 
        if (startBlit) blitRequested <= 1;
        if (currentBlitterState == BLITTER_END_DELAY) blitRequested <=0;
    end
end

logic input1_rd_en;
wire [7:0] input1_data;
blitter_in_fifo input_fifo1(
		.Data(data_in), //input [31:0] Data
		.WrClk(sdram_clk), //input WrClk
		.RdClk(blit_clk), //input RdClk
		.WrEn(blitterWr), //input WrEn
		.RdEn(input1_rd_en), //input RdEn
		.Q(input1_data) //output [7:0] Q

);
logic [7:0] output1_data;
logic output1_wr_en;
wire empty;
blitter_out_fifo output_fifo1(
		.Data(output1_data), //input [7:0] Data
		.WrClk(blit_clk), //input WrClk
		.RdClk(sdram_clk), //input RdClk
		.WrEn(output1_wr_en), //input WrEn
		.RdEn(blitterFifoRdEn), //input RdEn
		.Q(data_out), //output [31:0] Q
        .Empty(empty)

);
assign blitReady = (currentBlitterState==BLITTER_IDLE);

typedef enum logic [3:0] {
    BLITTER_IDLE,
    BLITTER_FILL_START,
    BLITTER_FILL_DO_X,
    BLITTER_FILL_COMMIT_LINE,
    BLITTER_FILL_COMMIT_DEACK,
    BLITTER_DONE,
    BLITTER_END_DELAY
    
} blitter_state_t;
blitter_state_t currentBlitterState;

logic [4:0] endDelay;

logic [15:0] xPos;
logic [15:0] yPos;
logic [15:0] destXandWidth;
logic firstWord;
logic [15:0] currentPatternRow;
always @(posedge blit_clk) begin 
output1_wr_en <= 0;
    if (rst) begin 
        currentBlitterState <= BLITTER_IDLE;
        fifoFillRequest <= 0;
        outputFifoCommitRequest <= 0;
        //blitReady <= 1;
    end else begin 
        case(currentBlitterState) 
            BLITTER_IDLE: begin 
                //blitReady <=1;
                if (blitRequested) begin 
                    //blitReady <=0;
                    case(blitterCmd) 
                        BLIT_CMD_FILL: begin 
                            currentBlitterState <= BLITTER_FILL_START;
                            xPos <= 0;
                            yPos <= dest_y;
                            blitter_line <= dest_y;
    
                            //TODO do line addr
                            fifoFillRequest <=1;
                            
                        end
                    endcase 
                end
            end
            BLITTER_FILL_START: begin 
                if (fifoFillAck & empty) begin 
                    fifoFillRequest <= 0;
                    currentBlitterState <= BLITTER_FILL_DO_X;
                    input1_rd_en <= 1;
                    firstWord <= 1;
                    currentPatternRow <= pattern[yPos[3:0]];
                end

            end
            BLITTER_FILL_DO_X: begin 
                
                output1_wr_en <= 1;
                output1_data <=  8'h00;

                if (firstWord) begin 
                       firstWord <= 0;
                        output1_data <=  8'h0f;
                    end
                output1_data <= input1_data;
                if ((xPos >= dest_x) & (xPos < dest_x+width)) begin 
                    if(patternFillMode[0]) output1_data <= (currentPatternRow[15 - xPos[3:0]])? (input1_data == fillData) ?fillBgCol:fillData: fillData;
                    else output1_data <= (currentPatternRow[15 - xPos[3:0]])? fillData: fillBgCol;

                    //case (patternFillMode) 
                       // PATTERN_MOD E_XOR: 
                    
                   //     default: 
                        
                   // endc ase
                    
                    //if(patternFillMode == PATTERN_MODE_XOR) output1_data <= (pattern[yPos][15-xPos])? (input1_data == fillData) ?fillBgCol:fillData: fillBgCol;
                end
       



                if (xPos < 1024) begin 
                    xPos <= xPos +1;
                end  else begin 
                    
                    currentBlitterState <= BLITTER_FILL_COMMIT_LINE;
                    outputFifoCommitRequest <=1;
                    xPos <= 0;
                end
            end
            BLITTER_FILL_COMMIT_LINE: begin 
                input1_rd_en <= 0;
                output1_wr_en <= 0;
                if (outputFifoCommitAck) begin 
                    outputFifoCommitRequest <= 0;
                    if (yPos < (dest_y+height -1)) begin 
                        yPos <= yPos +1;
                        blitter_line <= yPos +1;
                        currentBlitterState <= BLITTER_FILL_COMMIT_DEACK;
                    end else begin
                        endDelay <= 5;
                        currentBlitterState <= BLITTER_END_DELAY;//BLITTER_IDLE;
                    end
                end
            end
            BLITTER_END_DELAY: begin 
                if(endDelay==0) begin 
                    currentBlitterState <= BLITTER_IDLE;
                end else endDelay <= endDelay -1;
            end
            BLITTER_FILL_COMMIT_DEACK: begin 
                if (~outputFifoCommitAck) begin 
                    fifoFillRequest <=1;
                    currentBlitterState <= BLITTER_FILL_START;
                end
            end
        endcase


    end



end

endmodule