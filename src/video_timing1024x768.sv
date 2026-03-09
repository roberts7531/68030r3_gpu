module video_timing1024(
    input rst,
    input pix_clk,

    output de,
    output vs,
    output hs,

    output [10:0] sx,
    output [9:0] sy,

    output logic fifo_rd_en,

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

localparam int H_ACTIVE_VIDEO = 1024;
localparam int H_FRONT_PORCH = 24;
localparam int H_SYNC_PULSE = 136;
localparam int H_BACK_PORCH = 160;
localparam int H_TOTAL = H_ACTIVE_VIDEO + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

localparam int V_ACTIVE_VIDEO = 768;
localparam int V_FRONT_PORCH = 3;
localparam int V_SYNC_PULSE = 6;
localparam int V_BACK_PORCH = 29;
localparam int V_TOTAL = V_ACTIVE_VIDEO + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

assign data_len_32 = (H_ACTIVE_VIDEO /4) - 1;

logic [10:0] h_pos;
logic [9:0] v_pos;



always @(posedge pix_clk ) begin
    if (rst) begin 
        h_pos <= 0;
        v_pos <= 0;
    end else begin 
        h_pos <= h_pos + 1;
        if (h_pos == H_ACTIVE_VIDEO - 1) fifo_rd_en <= 0;
        if (h_pos == H_TOTAL - 1) begin 
            fifo_rd_en <= 1;
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
                lineToFill <= (v_pos == V_TOTAL -1) ? 0 : v_pos + 1;
            end
        if (line_fill_ack_sync[1]) line_fill_req <= 0;
    end
end



endmodule