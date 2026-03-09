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

wire cpu_in_cs = ~cpu_cs_n;
wire cpu_rd = ~cpu_rd_n;
wire cpu_uw = ~cpu_uw_n;
wire cpu_lw = ~cpu_lw_n;
wire cpu_dtack;
assign cpu_dtack_n = ~(cpu_dtack & cpu_cs);
assign cpu_int_n = 1;

assign cpu_data = (cpu_rd_sync) ? cpu_data_out : 16'bz;  // Drive or release
logic [20:0] cpu_addr_sync;
logic [20:0] cpu_addr_sync2;
logic [15:0] cpu_data_sync;
logic [15:0] cpu_data_sync2;
logic cpu_rd_sync, rd2;

logic [3:0] inputSyncDelay; 
logic cpu_in_sync,syn2;
logic cpu_cs;
always @(posedge sdram_clk)begin 
    syn2 <= cpu_in_cs;
    cpu_in_sync <= syn2;
    
    if(~cpu_in_sync) begin 
        inputSyncDelay <= 4;
        cpu_cs <= 0;
        divisor_rst <= 1;
        divisorDelay <= 11;
    end else begin 
        cpu_rd_sync <= cpu_rd;
        if(inputSyncDelay==0) begin 
            if(cpu_addr[20] | vram_stride == 0) begin 
                cpu_cs <= 1;
                cpu_addr_sync <= cpu_addr;
                cpu_data_sync <= cpu_data;
            end else begin
                divisor_rst<=0;
                if (divisorDelay ==0) begin 
                    cpu_cs <= 1;
                    cpu_addr_sync <= (cpu_y << 9) + cpu_x[10:1];
                    cpu_data_sync <= cpu_data;
                end else divisorDelay <= divisorDelay - 1'b1;
            end
        end else inputSyncDelay <= inputSyncDelay - 1'b1;
    end
end 
logic [3:0] divisorDelay;
logic divisor_rst;
wire [20:0] cpu_y;
wire [20:0] cpu_x;
Integer_Division_Top addrDivider(
		.clk(sdram_clk), //input clk
		.rstn(~divisor_rst), //input rstn
		.dividend({cpu_addr[19:0],1'b0}), //input [20:0] dividend
		.divisor(vram_stride), //input [10:0] divisor
		.remainder(cpu_x), //output [10:0] remainder
		.quotient(cpu_y) //output [20:0] quotient
	);
//tmds and pixel clocks
//Gowin_rPLL tmds_clk_pll(
//        .clkout(tmds_clk), //output clkout
//        .clkin(clk) //input clkin
//    );
wire tmds_lock;
Gowin_rPLL_dynamic dynpll(
        .clkout(tmds_clk), //output clkout
        .lock(tmds_lock), //output lock
        .clkin(clk), //input clkin
        .reset(~reset_n),
        .fbdsel((video_mode == 0 )? 6'b110100 : 6'b011011), //input [5:0] fbdsel
        .idsel((video_mode == 0 )? 6'b111111 : 6'b111000), //input [5:0] idsel
        .odsel((video_mode == 0 )? 6'b111111 : 6'b111100 ) //input [5:0] odsel
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

wire [15:0] cpu_data_out;
wire [9:0] lineToFill;
wire [7:0] fifo_burst_len;
wire [31:0] fifo_sdram_data_out;
reg [7:0] scrollY_vsync;
reg [7:0] scrollX_vsync;

logic [15:0] pattern [16];
wire blitReady;
always @(posedge sdram_clk) begin 
   // textCea <= 0;
    blitStart <= 0;
    if (I_rgb_vs) begin 
        scrollX_vsync <= scrollx;
        scrollY_vsync <= scrolly;
    end
    if (~reset_n) begin 
        blitStart <= 0;
        vram_stride <= 0;
        video_mode <= 0;
        scrollx <= 0;
        scrolly <= 0;
        textmode_mode <= 0;
    end else begin
        if(controlRegRd) begin 
            if (cpu_addr_sync[7:0] == REG_BLT_START) creg_data_in[0] <= blitReady;
        end else if (controlRegWr) begin 
                case (cpu_addr_sync[7:0]) 
                    REG_SCROLLY: scrolly <= cpu_data_sync[15:8];
                    REG_SCROLLX: scrollx <= cpu_data_sync[15:8];
                    REG_PAL_IDX: begin 
                        reds[cpu_data_sync[15:8]] <= pal_r;
                        greens[cpu_data_sync[15:8]] <= pal_g;
                        blues[cpu_data_sync[15:8]] <= pal_b;
                    end
                    REG_PAL_R: pal_r <= cpu_data_sync[15:8];
                    REG_PAL_G: pal_g <= cpu_data_sync[15:8];
                    REG_PAL_B: pal_b <= cpu_data_sync[15:8];
                    REG_SPR_XLOW: cursorX[7:0] <= cpu_data_sync[15:8];
                    REG_SPR_XHIGH: cursorX[11:8] <= cpu_data_sync[11:8];
                    REG_SPR_YLOW: cursorY[7:0] <= cpu_data_sync[15:8];
                    REG_SPR_YHIGH: cursorY[11:8] <= cpu_data_sync[11:8];
                    REG_SPR_IDX: spr_idx <= cpu_data_sync[15:8];
                    REG_SPR_DATA: begin 
                        if(spr_idx[0]) cursorSprite[spr_idx[7:1]][7:0] <= cpu_data_sync[15:8];
                        else cursorSprite[spr_idx[7:1]][15:8] <= cpu_data_sync[15:8];
                        spr_idx <= spr_idx + 8'd1;
                    end
                    REG_BLT_START: if (cpu_data_sync[15:8] == 8'h3a)  blitStart <= 1;
                    REG_BLT_CMD: blt_cmd <= cpu_data_sync[15:8];
                    REG_BLT_DESTX_LOW: blt_destx[7:0] <= cpu_data_sync[15:8];
                    REG_BLT_DESTX_HIGH: blt_destx[15:8] <= cpu_data_sync[15:8];
                    REG_BLT_DESTY_LOW: blt_desty[7:0] <= cpu_data_sync[15:8];
                    REG_BLT_DESTY_HIGH: blt_desty[15:8] <= cpu_data_sync[15:8];
                    REG_BLT_PAT_COL: blt_patt_col <= cpu_data_sync[15:8];
                    REG_BLT_PATT_DATA: begin 
                        blt_patt_idx <= blt_patt_idx + 1'b1;
                        if (blt_patt_idx[0]) pattern[blt_patt_idx[7:1]][7:0] <= cpu_data_sync[15:8];
                        else pattern[blt_patt_idx[7:1]][15:8] <= cpu_data_sync[15:8];
                    end
                    REG_BLT_PATT_IDX: blt_patt_idx <= cpu_data_sync[15:8];
                    REG_BLT_WIDTH_LOW: blt_width[7:0] <= cpu_data_sync[15:8];
                    REG_BLT_WIDTH_HIGH: blt_width[15:8] <= cpu_data_sync[15:8];
                    REG_BLT_HEIGHT_LOW: blt_height[7:0] <= cpu_data_sync[15:8];
                    REG_BLT_HEIGHT_HIGH: blt_height[15:8] <= cpu_data_sync[15:8];
                    REG_BLT_PAT_BGCOL: blt_pat_bgcol <= cpu_data_sync[15:8];
                    REG_BLT_PAT_MODE: blt_pat_mode <= cpu_data_sync[15:8];
                    REG_BLT_SRCX_LOW: blt_srcx[7:0] <= cpu_data_sync[15:8];
                    REG_BLT_SRCX_HIGH: blt_srcx[15:8] <= cpu_data_sync[15:8];
                    REG_BLT_SRCY_LOW: blt_srcy[7:0] <= cpu_data_sync[15:8];
                    REG_BLT_SRCY_HIGH: blt_srcy[15:8] <= cpu_data_sync[15:8];
                    REG_VRAM_STRIDE_LOW: vram_stride[7:0] <= cpu_data_sync[15:8];
                    REG_VRAM_STRIDE_HIGH: vram_stride[10:8] <= cpu_data_sync[15:8];
                    REG_VIDEO_MODE: begin 
                        video_mode <= cpu_data_sync[11:8];
                        video_subMode <= cpu_data_sync[15:12];
                    end
                    REG_TEXTMODE_INDEX_LOW: textmode_index[7:0] <= cpu_data_sync[15:8];
                    REG_TEXTMODE_INDEX_HIGH: textmode_index[12:8] <= cpu_data_sync[15:8];
                    REG_TEXTMODE_DATA: begin 
                        addrText <= textmode_index;
                        textDataIn <= cpu_data_sync[15:8];
                        textCea <= 1;
                        textmode_index <= textmode_index +1;
                    end
                    REG_TEXTMODE_MODE: textmode_mode[1:0] <= cpu_data_sync[15:8];
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
logic [7:0] blues [256];
logic [7:0] greens [256];
logic [7:0] reds [256] ;
localparam logic [7:0] REG_SPR_XLOW = 8'h06;
localparam logic [7:0] REG_SPR_XHIGH = 8'h07;
logic [11:0] cursorX;
localparam logic [7:0] REG_SPR_YLOW = 8'h08;
localparam logic [7:0] REG_SPR_YHIGH = 8'h09;
logic [11:0] cursorY;
localparam logic [7:0] REG_SPR_IDX = 8'h0a;
logic [7:0] spr_idx;
localparam logic [7:0] REG_SPR_DATA = 8'h0b;
logic [15:0] cursorSprite [16];
localparam logic [7:0] REG_BLT_START = 8'h0c;
reg blitStart;
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
localparam logic [7:0] REG_BLT_SRCX_LOW = 8'h1B;
localparam logic [7:0] REG_BLT_SRCX_HIGH = 8'h1C;
logic [15:0] blt_srcx;
localparam logic [7:0] REG_BLT_SRCY_LOW = 8'h1D;
localparam logic [7:0] REG_BLT_SRCY_HIGH = 8'h1E;
logic [15:0] blt_srcy;
localparam logic [7:0] REG_VRAM_STRIDE_LOW = 8'h1F;
localparam logic [7:0] REG_VRAM_STRIDE_HIGH = 8'h20;
logic [10:0] vram_stride;
localparam logic [7:0] REG_VIDEO_MODE = 8'h21;
logic [3:0] video_mode;
logic [3:0] video_subMode;
localparam logic [7:0] REG_TEXTMODE_INDEX_LOW = 8'h22;
localparam logic [7:0] REG_TEXTMODE_INDEX_HIGH = 8'h23;
logic [12:0] textmode_index;
localparam logic [7:0] REG_TEXTMODE_DATA = 8'h24;
localparam logic [7:0] REG_TEXTMODE_MODE = 8'h25;
logic [1:0] textmode_mode;




wire [31:0] blitter_data_in;
wire [12:0] blitter_line;
wire [7:0] blitterXoffset;
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
    .x_scroll(scrollX_vsync[7:2]),
    .cs_raw(cpu_in_cs),
    //cpu interface
    .cpu_addr(cpu_addr_sync),
    .cpu_sdram_data_in(cpu_data_sync),
    .cpu_cs,
    .rd_raw(cpu_rd),
    .cpu_uw,
    .cpu_lw,
    .cpu_data_out,
    .cpu_dtack,
    .creg_busy(~blitReady),
    //control reg stuff
    .controlRegWr,
    .controlRegRd,
    .creg_data_in,
    // blitter interface 
    .blitter_fifo_wr,
    .blitter_fifo_fill_req,
    .blitter_line,
    .blitter_data_in,
    .blitter_fifo_rd_en,
    .blitter_fifo_commit_req,
    .blitter_ack,
    .blitReady,
    .blitterXoffset,
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
blitter blitterinst (
    .rst(~reset_n),
    .blit_clk(sdram_clk),

    .i_dest_x(blt_destx),
    .i_dest_y(blt_desty),
    .i_src_x(blt_srcx),
    .i_src_y(blt_srcy),
    .i_width(blt_width),
    .i_height(blt_height),
    .i_pattern(pattern),
    .i_fillData(blt_patt_col),
    .i_fillBgCol(blt_pat_bgcol),
    .i_patternFillMode(blt_pat_mode),
    .i_blitterCmd(blt_cmd),
    .startBlit(blitStart),
    .blitReady(blitReady),

    .blitterXoffset,
    .blitter_line,
    .data_in(fifo_sdram_data_out),
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
		.Q(fifo_data_out) //output [7:0] Q
	);


wire [10:0] sx640;
wire [10:0] sx1024;
wire [10:0] sx = (video_mode == 0) ? sx1024: sx640;

wire [9:0] sy640;
wire [9:0] sy1024;
wire [9:0] sy = (video_mode == 0) ? sy1024: sy640;

wire fifo_rd_en1024;
wire fifo_rd_en640;
assign fifo_rd_en = (video_mode == 0) ? fifo_rd_en1024 : fifo_rd_en640;

wire de1024,de640;
assign I_rgb_de = (video_mode == 0) ? de1024 : de640;
wire vs1024,vs640;
assign I_rgb_vs = (video_mode == 0) ? vs1024 : vs640;
wire hs1024,hs640;
assign I_rgb_hs = (video_mode == 0) ? hs1024 : hs640;

wire [7:0] data_len_1024;
wire [7:0] data_len_640;
assign fifo_burst_len = (video_mode == 0) ? data_len_1024 : data_len_640;

wire [9:0] lineToFill_1024;
wire [9:0] lineToFill_640;
assign lineToFill = (video_mode == 0) ? lineToFill_1024 : lineToFill_640;

wire lineFillReq1024;
wire lineFillReq640;
assign fifo_line_fill_req = (video_mode == 0) ? lineFillReq1024 : lineFillReq640;
video_timing1024 highresMode(
    .rst(~reset_n | (video_mode == 1)),
    .pix_clk(pix_clk),

    .de(de1024),
    .vs(vs1024),
    .hs(hs1024),

    .sx(sx1024),
    .sy(sy1024),

    .fifo_rd_en(fifo_rd_en1024),

    .data_len_32(data_len_1024),
    .lineToFill(lineToFill_1024),
    .line_fill_req(lineFillReq1024),
    .line_fill_ack(fifo_line_fill_ack)
); 
video_timing640 lowresMode(
    .rst(~reset_n | (video_mode == 0)),
    .pix_clk(pix_clk),

    .de(de640),
    .vs(vs640),
    .hs(hs640),
    .scrollX(scrollX_vsync[1:0]),
    .sx(sx640),
    .sy(sy640),
    .doubleSize(video_subMode[0]),
    .fifo_rd_en(fifo_rd_en640),

    .data_len_32(data_len_640),
    .lineToFill(lineToFill_640),
    .line_fill_req(lineFillReq640),
    .line_fill_ack(fifo_line_fill_ack)
); 
logic [7:0] font [1792] = '{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h40,8'he0,8'he0,8'h40,8'h40,8'h00,8'h40,8'h00,8'hd8,8'hd8,8'hd8,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h50,8'hf8,8'h50,8'h50,8'hf8,8'h50,8'h00,8'h40,8'h70,8'h80,8'h60,8'h10,8'he0,8'h20,8'h00,8'hc8,8'hc8,8'h10,8'h20,8'h40,8'h98,8'h98,8'h00,8'h40,8'ha0,8'ha0,8'h40,8'ha8,8'h90,8'h68,8'h00,8'hc0,8'hc0,8'hc0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h40,8'h80,8'h80,8'h80,8'h80,8'h80,8'h40,8'h00,8'h80,8'h40,8'h40,8'h40,8'h40,8'h40,8'h80,8'h00,8'h00,8'h50,8'h70,8'hf8,8'h70,8'h50,8'h00,8'h00,8'h00,8'h20,8'h20,8'hf8,8'h20,8'h20,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hc0,8'hc0,8'h40,8'h00,8'h00,8'h00,8'hf8,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hc0,8'hc0,8'h00,8'h00,8'h08,8'h10,8'h20,8'h40,8'h80,8'h00,8'h00,8'h70,8'h88,8'h98,8'ha8,8'hc8,8'h88,8'h70,8'h00,8'h40,8'hc0,8'h40,8'h40,8'h40,8'h40,8'he0,8'h00,8'h70,8'h88,8'h08,8'h30,8'h40,8'h80,8'hf8,8'h00,8'h70,8'h88,8'h08,8'h70,8'h08,8'h88,8'h70,8'h00,8'h10,8'h30,8'h50,8'h90,8'hf8,8'h10,8'h10,8'h00,8'hf8,8'h80,8'h80,8'hf0,8'h08,8'h88,8'h70,8'h00,8'h30,8'h40,8'h80,8'hf0,8'h88,8'h88,8'h70,8'h00,8'hf8,8'h08,8'h10,8'h20,8'h40,8'h40,8'h40,8'h00,8'h70,8'h88,8'h88,8'h70,8'h88,8'h88,8'h70,8'h00,8'h70,8'h88,8'h88,8'h78,8'h08,8'h10,8'h60,8'h00,8'h00,8'h00,8'hc0,8'hc0,8'h00,8'hc0,8'hc0,8'h00,8'h00,8'h00,8'hc0,8'hc0,8'h00,8'hc0,8'hc0,8'h80,8'h10,8'h20,8'h40,8'h80,8'h40,8'h20,8'h10,8'h00,8'h00,8'h00,8'hf8,8'h00,8'h00,8'hf8,8'h00,8'h00,8'h80,8'h40,8'h20,8'h10,8'h20,8'h40,8'h80,8'h00,8'h70,8'h88,8'h08,8'h30,8'h20,8'h00,8'h20,8'h00,8'h70,8'h88,8'hb8,8'ha8,8'hb8,8'h80,8'h70,8'h00,8'h70,8'h88,8'h88,8'h88,8'hf8,8'h88,8'h88,8'h00,8'hf0,8'h88,8'h88,8'hf0,8'h88,8'h88,8'hf0,8'h00,8'h70,8'h88,8'h80,8'h80,8'h80,8'h88,8'h70,8'h00,8'hf0,8'h88,8'h88,8'h88,8'h88,8'h88,8'hf0,8'h00,8'hf8,8'h80,8'h80,8'hf0,8'h80,8'h80,8'hf8,8'h00,8'hf8,8'h80,8'h80,8'hf0,8'h80,8'h80,8'h80,8'h00,8'h70,8'h88,8'h80,8'hb8,8'h88,8'h88,8'h78,8'h00,8'h88,8'h88,8'h88,8'hf8,8'h88,8'h88,8'h88,8'h00,8'he0,8'h40,8'h40,8'h40,8'h40,8'h40,8'he0,8'h00,8'h08,8'h08,8'h08,8'h08,8'h88,8'h88,8'h70,8'h00,8'h88,8'h90,8'ha0,8'hc0,8'ha0,8'h90,8'h88,8'h00,8'h80,8'h80,8'h80,8'h80,8'h80,8'h80,8'hf8,8'h00,8'h88,8'hd8,8'ha8,8'h88,8'h88,8'h88,8'h88,8'h00,8'h88,8'hc8,8'ha8,8'h98,8'h88,8'h88,8'h88,8'h00,8'h70,8'h88,8'h88,8'h88,8'h88,8'h88,8'h70,8'h00,8'hf0,8'h88,8'h88,8'hf0,8'h80,8'h80,8'h80,8'h00,8'h70,8'h88,8'h88,8'h88,8'ha8,8'h90,8'h68,8'h00,8'hf0,8'h88,8'h88,8'hf0,8'h90,8'h88,8'h88,8'h00,8'h70,8'h88,8'h80,8'h70,8'h08,8'h88,8'h70,8'h00,8'hf8,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20,8'h00,8'h88,8'h88,8'h88,8'h88,8'h88,8'h88,8'h70,8'h00,8'h88,8'h88,8'h88,8'h88,8'h88,8'h50,8'h20,8'h00,8'ha8,8'ha8,8'ha8,8'ha8,8'ha8,8'ha8,8'h50,8'h00,8'h88,8'h88,8'h50,8'h20,8'h50,8'h88,8'h88,8'h00,8'h88,8'h88,8'h88,8'h50,8'h20,8'h20,8'h20,8'h00,8'hf0,8'h10,8'h20,8'h40,8'h80,8'h80,8'hf0,8'h00,8'he0,8'h80,8'h80,8'h80,8'h80,8'h80,8'he0,8'h00,8'h00,8'h80,8'h40,8'h20,8'h10,8'h08,8'h00,8'h00,8'he0,8'h20,8'h20,8'h20,8'h20,8'h20,8'he0,8'h00,8'h20,8'h50,8'h88,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hf8,8'hc0,8'hc0,8'h40,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h70,8'h08,8'h78,8'h88,8'h78,8'h00,8'h80,8'h80,8'hf0,8'h88,8'h88,8'h88,8'hf0,8'h00,8'h00,8'h00,8'h70,8'h88,8'h80,8'h88,8'h70,8'h00,8'h08,8'h08,8'h78,8'h88,8'h88,8'h88,8'h78,8'h00,8'h00,8'h00,8'h70,8'h88,8'hf0,8'h80,8'h70,8'h00,8'h30,8'h40,8'h40,8'hf0,8'h40,8'h40,8'h40,8'h00,8'h00,8'h00,8'h78,8'h88,8'h88,8'h78,8'h08,8'h70,8'h80,8'h80,8'he0,8'h90,8'h90,8'h90,8'h90,8'h00,8'h80,8'h00,8'h80,8'h80,8'h80,8'h80,8'hc0,8'h00,8'h10,8'h00,8'h30,8'h10,8'h10,8'h10,8'h90,8'h60,8'h80,8'h80,8'h90,8'ha0,8'hc0,8'ha0,8'h90,8'h00,8'h80,8'h80,8'h80,8'h80,8'h80,8'h80,8'hc0,8'h00,8'h00,8'h00,8'hd0,8'ha8,8'ha8,8'h88,8'h88,8'h00,8'h00,8'h00,8'he0,8'h90,8'h90,8'h90,8'h90,8'h00,8'h00,8'h00,8'h70,8'h88,8'h88,8'h88,8'h70,8'h00,8'h00,8'h00,8'hf0,8'h88,8'h88,8'h88,8'hf0,8'h80,8'h00,8'h00,8'h78,8'h88,8'h88,8'h88,8'h78,8'h08,8'h00,8'h00,8'hb0,8'h48,8'h40,8'h40,8'he0,8'h00,8'h00,8'h00,8'h70,8'h80,8'h70,8'h08,8'h70,8'h00,8'h40,8'h40,8'hf0,8'h40,8'h40,8'h50,8'h20,8'h00,8'h00,8'h00,8'h90,8'h90,8'h90,8'hb0,8'h50,8'h00,8'h00,8'h00,8'h88,8'h88,8'h88,8'h50,8'h20,8'h00,8'h00,8'h00,8'h88,8'h88,8'ha8,8'hf8,8'h50,8'h00,8'h00,8'h00,8'h90,8'h90,8'h60,8'h90,8'h90,8'h00,8'h00,8'h00,8'h90,8'h90,8'h90,8'h70,8'h20,8'hc0,8'h00,8'h00,8'hf0,8'h10,8'h60,8'h80,8'hf0,8'h00,8'h30,8'h40,8'h40,8'hc0,8'h40,8'h40,8'h30,8'h00,8'h80,8'h80,8'h80,8'h00,8'h80,8'h80,8'h80,8'h00,8'hc0,8'h20,8'h20,8'h30,8'h20,8'h20,8'hc0,8'h00,8'h50,8'ha0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00,8'hfc,8'h84,8'h84,8'h84,8'h84,8'h84,8'hfc,8'h00};
wire [7:0] dataOutDPB;
wire [10:0] sxplus1 = sx+1;
wire [6:0] char_x =sxplus1[10:3];// 8; // 0..79
wire [9:0] char_y = sy[9:3]; // 8; // 0..59

wire [12:0] char_index = (char_y<<6) + (char_y<<4) + char_x;
logic [7:0] textDataIn;
logic textCea; 
logic [12:0] addrText;
Gowin_SDPB textBuffer(
        .dout(dataOutDPB), //output [7:0] dout
        .clka(sdram_clk), //input clka
        .cea(textCea), //input cea
        .reseta(~reset_n), //input reseta
        .clkb(pix_clk), //input clkb
        .ceb(1), //input ceb
        .resetb(~reset_n), //input resetb
        .oce(1), //input oce
        .ada(addrText), //input [12:0] ada
        .din(textDataIn), //input [7:0] din
        .adb((char_index <4800) ? char_index : 0) //input [12:0] adb
    );



// fetch font pixel, blank if outside area
wire fontPixelValid = (char_x < 80 && char_y < 60 && char_x > 0);
wire fontPixelValidMode = (textmode_mode == 0) ? fontPixelValid :
                          (textmode_mode == 1) ? fontPixelValid && (char_y) > 51 : 0;
wire [7:0] char_code = fontPixelValidMode ? dataOutDPB : 8'd0;
wire [10:0] font_row = ((char_code - 8'd32) << 3) + sy[2:0];
wire fontPixel = fontPixelValidMode ? font[font_row][7-sx[2:0]] : 1'b0;
//wire fontPixel = font[(8'h41-8'd32)*8 + sy[2:0]][8-sx[2:0]];
wire cursorActive = (sx >= cursorX && sx<cursorX+12'd16) && (sy >= cursorY && sy<cursorY+12'd16); 
wire [3:0] cx = sx - cursorX;   // 0..15
wire [3:0] cy = sy - cursorY;   // 0..15

wire cursorPixel = cursorActive 
                   ? cursorSprite[cy][15 - cx] 
                   : 1'b0;
wire [7:0] bg_r = reds[fifo_data_out];
wire [7:0] bg_g = greens[fifo_data_out];
wire [7:0] bg_b = blues[fifo_data_out];

wire [7:0] inv_r = ~bg_r;
wire [7:0] inv_g = ~bg_g;
wire [7:0] inv_b = ~bg_b;

wire [7:0] r = cursorPixel ? 8'H20 : (fontPixel ? inv_r : bg_r);
wire [7:0] g = cursorPixel ? 8'h10 : (fontPixel ? inv_g : bg_g);
wire [7:0] b = cursorPixel ? 8'h10 : (fontPixel ? inv_b : bg_b);
wire [7:0] I_rgb_r = (I_rgb_de) ? r : 0;
wire [7:0] I_rgb_g = (I_rgb_de) ? g : 0;
wire [7:0] I_rgb_b = (I_rgb_de) ? b : 0;

DVI_TX_Top hdmi(
		.I_rst_n(reset_n ), //input I_rst_n
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
endmodule