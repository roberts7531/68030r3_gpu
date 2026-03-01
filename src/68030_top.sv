module top_level ( 
    // Clock and reset
    input  wire        clk,
    input  wire        reset_n,

    output       O_tmds_clk_po,
    output       O_tmds_clk_ne,
    output [2:0] O_tmds_data_po,
    output [2:0] O_tmds_data_ne,

    // 68k CPU interface (example)
    inout  wire [15:0] cpu_data,   // Data bus from CPU
    input  wire [20:0] cpu_addr,      // Address bus
    input  wire        cpu_cs_n,      // Address strobe
    input  wire        cpu_uw_n,     // Upper data strobe
    input  wire        cpu_lw_n,     // Lower data strobe
    input  wire        cpu_rd_n,        // Read / Write

    // Video interface (example)
    output wire        cpu_int_n,
    output wire        cpu_dtack_n,


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

wire cpu_cs = ~cpu_cs_n;
wire cpu_rd = ~cpu_rd_n;
wire cpu_uw = ~cpu_uw_n;
wire cpu_lw = ~cpu_lw_n;
reg dtack;
wire cpu_dtack;
assign cpu_dtack_n = ~cpu_dtack;

assign cpu_int_n = 1;

assign cpu_data = (cpu_rd) ? cpu_sdram_data_out : 16'bz;  // Drive or release


//tmds and pixel clocks
Gowin_rPLL tmds_clk_pll(
        .clkout(tmds_clk), //output clkout
        .clkin(clk) //input clkin
    );
Gowin_CLKDIV pix_clk_clkdiv(
        .clkout(pix_clk), //output clkout
        .hclkin(tmds_clk), //input hclkin
        .resetn(reset_n) //input resetn
    );
//sdram clock
Gowin_rPLL2 sdr_clk_pll(
        .clkout(sdram_clk), //output clkout
        .lock(sdram_pll_lock), //output lock
        .clkin(clk) //input clkin
    );

wire [15:0] cpu_sdram_data_out;
wire [9:0] lineToFill;
wire [7:0] fifo_burst_len;
wire [31:0] fifo_sdram_data_out;
reg [7:0] scrollY_vsync;
reg [7:0] scrollX_vsync;
//reg [7:0] creg [0:50];

integer i;
logic [15:0] pattern [16];
wire blitReady;
always @(posedge sdram_clk) begin 
    blitStart <= 0;
    if (I_rgb_vs) begin 
        scrollX_vsync <= scrollx;
        scrollY_vsync <= scrolly;
    end
    if (~reset_n) begin 
       // for (i = 0; i < 50; i = i + 1)
        //    creg[i] <= 8'h00;
                blitStart <= 0;

    end else begin
        if(controlRegRd) begin 
            if (cpu_addr[7:0] == REG_BLT_START) creg_data_in[0] <= blitReady;
        end else if (controlRegWr) begin 
            case (cpu_addr[7:0]) 
                REG_SCROLLY: scrolly <= cpu_data[15:8];
                REG_SCROLLX: scrollx <= cpu_data[15:8];
                REG_PAL_IDX: begin 
                    reds[cpu_data[15:8]] <= pal_r;
                    greens[cpu_data[15:8]] <= pal_g;
                    blues[cpu_data[15:8]] <= pal_b;
                end
                REG_PAL_R: pal_r <= cpu_data[15:8];
                REG_PAL_G: pal_g <= cpu_data[15:8];
                REG_PAL_B: pal_b <= cpu_data[15:8];
                REG_SPR_XLOW: cursorX[7:0] <= cpu_data[15:8];
                REG_SPR_XHIGH: cursorX[11:8] <= cpu_data[11:8];
                REG_SPR_YLOW: cursorY[7:0] <= cpu_data[15:8];
                REG_SPR_YHIGH: cursorY[11:8] <= cpu_data[11:8];
                REG_SPR_IDX: spr_idx <= cpu_data[15:8];
                REG_SPR_DATA: begin 
                    if(spr_idx[0]) cursorSprite[spr_idx[7:1]][7:0] <= cpu_data[15:8];
                    else cursorSprite[spr_idx[7:1]][15:8] <= cpu_data[15:8];
                    spr_idx <= spr_idx + 8'd1;
                end
                REG_BLT_START: if (cpu_data[15:8] == 8'h3a)  blitStart <= 1;
                REG_BLT_CMD: blt_cmd <= cpu_data[15:8];
                REG_BLT_DESTX_LOW: blt_destx[7:0] <= cpu_data[15:8];
                REG_BLT_DESTX_HIGH: blt_destx[15:8] <= cpu_data[15:8];
                REG_BLT_DESTY_LOW: blt_desty[7:0] <= cpu_data[15:8];
                REG_BLT_DESTY_HIGH: blt_desty[15:8] <= cpu_data[15:8];
                REG_BLT_PAT_COL: blt_patt_col <= cpu_data[15:8];
                REG_BLT_PATT_DATA: begin 
                    blt_patt_idx <= blt_patt_idx + 1;
                    if (blt_patt_idx[0]) pattern[blt_patt_idx[7:1]][7:0] <= cpu_data[15:8];
                    else pattern[blt_patt_idx[7:1]][15:8] <= cpu_data[15:8];
                end
                REG_BLT_PATT_IDX: blt_patt_idx <= cpu_data[15:8];
                REG_BLT_WIDTH_LOW: blt_width[7:0] <= cpu_data[15:8];
                REG_BLT_WIDTH_HIGH: blt_width[15:8] <= cpu_data[15:8];
                REG_BLT_HEIGHT_LOW: blt_height[7:0] <= cpu_data[15:8];
                REG_BLT_HEIGHT_HIGH: blt_height[15:8] <= cpu_data[15:8];
                REG_BLT_PAT_BGCOL: blt_pat_bgcol <= cpu_data[15:8];
                REG_BLT_PAT_MODE: blt_pat_mode <= cpu_data[15:8];
            endcase
        end
    end

end
wire  controlRegRd, controlRegWr;
logic [7:0] creg_data_in;

localparam logic [7:0] REG_SCROLLY = 8'h00;
logic [7:0] scrolly;
localparam logic [7:0] REG_SCROLLX = 8'h01;
logic [7:0] scrollx;
localparam logic [7:0] REG_PAL_IDX = 8'h02;
logic [7:0] pal_idx;
localparam logic [7:0] REG_PAL_R = 8'h03;
logic [7:0] pal_r;
localparam logic [7:0] REG_PAL_G = 8'h04;
logic [7:0] pal_g;
localparam logic [7:0] REG_PAL_B = 8'h05;
logic [7:0] pal_b;
localparam logic [7:0] REG_SPR_XLOW = 8'h06;
localparam logic [7:0] REG_SPR_XHIGH = 8'h07;
localparam logic [7:0] REG_SPR_YLOW = 8'h08;
localparam logic [7:0] REG_SPR_YHIGH = 8'h09;
localparam logic [7:0] REG_SPR_IDX = 8'h0a;
logic [7:0] spr_idx;
localparam logic [7:0] REG_SPR_DATA = 8'h0b;
localparam logic [7:0] REG_BLT_START = 8'h0c;
localparam logic [7:0] REG_BLT_CMD = 8'h0d;
logic [7:0] blt_cmd;
localparam logic [7:0] REG_BLT_DESTX_LOW = 8'h0e;
localparam logic [7:0] REG_BLT_DESTX_HIGH = 8'h0f;
logic [15:0] blt_destx;
localparam logic [7:0] REG_BLT_DESTY_LOW = 8'h10;
localparam logic [7:0] REG_BLT_DESTY_HIGH = 8'h11;
logic [15:0] blt_desty;
localparam logic [7:0] REG_BLT_PAT_COL = 8'h12;
logic [7:0] blt_patt_col;
localparam logic [7:0] REG_BLT_PATT_DATA = 8'h13;
logic [7:0] blt_patt_data;
localparam logic [7:0] REG_BLT_PATT_IDX = 8'h14;
logic [7:0] blt_patt_idx;
localparam logic [7:0] REG_BLT_WIDTH_LOW = 8'h15;
localparam logic [7:0] REG_BLT_WIDTH_HIGH = 8'h16;
logic [15:0] blt_width;
localparam logic [7:0] REG_BLT_HEIGHT_LOW = 8'h17;
localparam logic [7:0] REG_BLT_HEIGHT_HIGH = 8'h18;
logic [15:0] blt_height;
localparam logic [7:0] REG_BLT_PAT_BGCOL = 8'h19;
logic [7:0] blt_pat_bgcol;
localparam logic [7:0] REG_BLT_PAT_MODE = 8'h1A;
logic [7:0] blt_pat_mode;







wire [7:0] cregAddr;
wire [31:0] blitter_data_out;
wire [31:0] blitter_data_in;
wire [9:0] blitter_line;
wire blitter_ack;
sdram_interface sdram_interface_inst(
    .clk(sdram_clk),
    .reset_n(reset_n & sdram_pll_lock),


    //fifo interface
    .fifo_line_fill_req,
    .fifo_burst_len,
    .fifo_line_fill_ack,
    .fifo_line_to_fill(lineToFill + scrollY_vsync),
    .fifo_write_en,
    .fifo_sdram_data_out,
    .x_scroll(scrollX_vsync),

    //cpu interface
    .cpu_addr,
    .cpu_sdram_data_in(cpu_data),
    .cpu_cs,
    .cpu_rd,
    .cpu_uw,
    .cpu_lw,
    .cpu_sdram_data_out,
    .cpu_dtack,

    //control reg stuff
    .controlRegWr,
    .controlRegRd,
    .creg_data_in,
    // blitter interface 
    .blitter_data_out,//output [31:0] blitter_data_out,
    .blitter_fifo_wr,
    .blitter_fifo_fill_req,
    .blitter_line,
    .blitter_data_in,
    .blitter_fifo_rd_en,
    .blitter_fifo_commit_req,
    .blitter_ack,

    //sdram interface
    .O_sdram_clk,
	.O_sdram_cke,
	.O_sdram_cs_n,
	.O_sdram_cas_n,
	.O_sdram_ras_n,
	.O_sdram_wen_n,
	.O_sdram_dqm,
	.O_sdram_addr,
	.O_sdram_ba,
	.IO_sdram_dq
); 
reg blitStart;
blitter blitterinst (
    .rst(~reset_n),
    .blit_clk(sdram_clk),
    .sdram_clk(sdram_clk),

    .dest_x(blt_destx),
    .dest_y(blt_desty),

    .width(blt_width),
    .height(blt_height),
    .pattern(pattern),
    .fillData(blt_patt_col),
    .fillBgCol(blt_pat_bgcol),
    .patternFillMode(blt_pat_mode),
    .blitterCmd(blt_cmd),
    .startBlit(blitStart),
    .blitReady(blitReady),


    .blitter_line,
    .data_in(blitter_data_out),
    .blitterWr(blitter_fifo_wr),
    .fifoFillRequest(blitter_fifo_fill_req),
    .fifoFillAck(blitter_ack),
       
    .data_out(blitter_data_in),
    .blitterFifoRdEn(blitter_fifo_rd_en),
    .outputFifoCommitRequest(blitter_fifo_commit_req),
    .outputFifoCommitAck(blitter_ack)

);

wire [7:0] fifo_data_out;
FIFO_HS_Top pixel_fifo(
		.Data(fifo_sdram_data_out), //input [31:0] Data
		.WrClk(sdram_clk), //input WrClk
		.RdClk(pix_clk), //input RdClk
		.WrEn(fifo_write_en), //input WrEn
		.RdEn(fifo_rd_en), //input RdEn
		.Q(fifo_data_out), //output [7:0] Q
		.Empty(Empty_o), //output Empty 
		.Full(Full_o) //output Full
	);
wire [10:0] sx;
wire [9:0] sy;
video_timing1024 highresMode(
    .rst(~reset_n),
    .pix_clk(pix_clk),

    .de(I_rgb_de),
    .vs(I_rgb_vs),
    .hs(I_rgb_hs),

    .sx(sx),
    .sy(sy),

    .fifo_rd_en,

    .data_len_32(fifo_burst_len),
    .lineToFill,
    .line_fill_req(fifo_line_fill_req),
    .line_fill_ack(fifo_line_fill_ack)
); 


//wire reset_n;
//assign reset_n = 1;
wire [21:0] address_for_scope;
assign address_for_scope = {cpu_addr[20:1], 1'b0}; // safe: A0=0 for display only



wire [7:0] I_rgb_r;
wire [7:0] I_rgb_g;
wire [7:0] I_rgb_b;

DVI_TX_Top hdmi(
		.I_rst_n(reset_n), //input I_rst_n
		.I_serial_clk(tmds_clk), //input I_serial_clk
		.I_rgb_clk(pix_clk), //input I_rgb_clk
		.I_rgb_vs(I_rgb_vs), //input I_rgb_vs
		.I_rgb_hs(I_rgb_hs), //input I_rgb_hs
		.I_rgb_de(I_rgb_de), //input I_rgb_de
		.I_rgb_r(I_rgb_r), //input [7:0] I_rgb_r
		.I_rgb_g(I_rgb_g), //input [7:0] I_rgb_g
		.I_rgb_b(I_rgb_b), //input [7:0] I_rgb_b
		.O_tmds_clk_p(O_tmds_clk_po), //output O_tmds_clk_p
		.O_tmds_clk_n(O_tmds_clk_ne), //output O_tmds_clk_n
		.O_tmds_data_p(O_tmds_data_po), //output [2:0] O_tmds_data_p
		.O_tmds_data_n(O_tmds_data_ne) //output [2:0] O_tmds_data_n
	);
wire [9:0] xPos;
logic [11:0] cursorX = 12'd100;
logic [11:0] cursorY = 12'd100;
logic [15:0] cursorSprite [16];
wire cursorActive = (sx >= cursorX && sx<cursorX+12'd16) && (sy >= cursorY && sy<cursorY+12'd16); 
wire [3:0] cx = sx - cursorX;   // 0..15
wire [3:0] cy = sy - cursorY;   // 0..15

wire cursorPixel = cursorActive 
                   ? cursorSprite[cy][15 - cx] 
                   : 1'b0;

assign I_rgb_r = (I_rgb_de) ? r : 0;
assign I_rgb_g = (I_rgb_de) ? g : 0;
assign I_rgb_b = (I_rgb_de) ? b : 0;
wire [7:0] r;
wire [7:0] g;
wire [7:0] b;
logic [7:0] blues [256];
logic [7:0] greens [256];
logic [7:0] reds [256] ;
assign r = (cursorPixel) ? 8'h00 : reds[fifo_data_out];
assign g = (cursorPixel) ? 8'h00 : greens[fifo_data_out];
assign b = (cursorPixel) ? 8'h00 : blues[fifo_data_out];
endmodule