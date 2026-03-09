module video_timing640(
    input rst,
    input pix_clk,

    output de,
    output vs,
    output hs,
    input doubleSize,
    output [10:0] sx,
    output [9:0] sy,

    output logic fifo_rd_en,
    input [1:0] scrollX,

    output [7:0] data_len_32,
    output logic [9:0] lineToFill,
    output logic line_fill_req,
    input line_fill_ack
); 
logic [1:0] line_fill_ack_sync;
always @(posedge pix_clk) begin 
    line_fill_ack_sync <= {line_fill_ack_sync[0],line_fill_ack};
end

//ActiveVideo 	FrontPorch 	SyncPulse 	BackPorch 	ActiveVideo 	FrontPorch 	SyncPulse 	BackPorch
//640	        16	        96	        48 	        480	            11	        2	        31
assign de = (h_pos < H_ACTIVE_VIDEO) && (v_pos < V_ACTIVE_VIDEO) ;
assign vs = (v_pos >= V_ACTIVE_VIDEO + V_FRONT_PORCH) && (v_pos < V_ACTIVE_VIDEO + V_FRONT_PORCH + V_SYNC_PULSE);
assign hs = (h_pos >= H_ACTIVE_VIDEO + H_FRONT_PORCH) && (h_pos < H_ACTIVE_VIDEO + H_FRONT_PORCH + H_SYNC_PULSE);
assign sx = h_pos;
assign sy = v_pos;

localparam int H_ACTIVE_VIDEO = 640;
localparam int H_FRONT_PORCH = 16;
localparam int H_SYNC_PULSE = 96;
localparam int H_BACK_PORCH = 48;
localparam int H_TOTAL = H_ACTIVE_VIDEO + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

localparam int V_ACTIVE_VIDEO = 480;
localparam int V_FRONT_PORCH = 11;
localparam int V_SYNC_PULSE = 2;
localparam int V_BACK_PORCH = 31;
localparam int V_TOTAL = V_ACTIVE_VIDEO + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

assign data_len_32 = ((doubleSize) ? H_ACTIVE_VIDEO/8 : H_ACTIVE_VIDEO /4) - 1;

logic [10:0] h_pos;
logic [9:0] v_pos;


logic fifoRdOn;
always @(posedge pix_clk ) begin
    if (rst) begin 
        h_pos <= 0;
        v_pos <= 0;
    end else begin 
        h_pos <= h_pos + 1;
        if(fifoRdOn & doubleSize) fifo_rd_en <= doubleSize ? h_pos[0] : 1'b1;
        if (h_pos == H_ACTIVE_VIDEO ) begin 
            fifo_rd_en <= 0;
            fifoRdOn <= 0;
        end
        if (h_pos == (H_TOTAL - 1 - scrollX)) begin 
            fifo_rd_en <= 1;
            fifoRdOn <= 1;
        end
        if (h_pos == H_TOTAL - 1) begin 
            
            h_pos <= 0;
            v_pos <= v_pos + 1;
            if (v_pos == V_TOTAL - 1) begin 
                v_pos <= 0;
            end
        end
    end
end

always @(posedge pix_clk) begin 
    if (rst) begin 
        line_fill_req <= 0;
    end else begin 
        if (h_pos == H_ACTIVE_VIDEO -1) begin 
                line_fill_req <= 1; 
                if(doubleSize) lineToFill <= (v_pos == V_TOTAL -1) ? 0 : (v_pos + 1)>>1;
                else lineToFill <= (v_pos == V_TOTAL -1) ? 0 : v_pos + 1;
            end
        if (line_fill_ack_sync[1]) line_fill_req <= 0;
    end
end



endmodule