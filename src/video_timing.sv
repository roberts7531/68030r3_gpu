module video_timing(
    input rst,
    input pix_clk,

    output de,
    output vs,
    output hs,

    output [9:0] sx,
    output [9:0] sy 
); 
//ActiveVideo 	FrontPorch 	SyncPulse 	BackPorch 	ActiveVideo 	FrontPorch 	SyncPulse 	BackPorch
//640	        16	        96	        48 	        480	            11	        2	        31
assign de = (h_pos < H_ACTIVE_VIDEO) && (v_pos < V_ACTIVE_VIDEO);
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
logic [9:0] h_pos;
logic [9:0] v_pos;

always @(posedge pix_clk ) begin
    if (rst) begin 
        h_pos <= 0;
        v_pos <= 0;
    end else begin 
        h_pos <= h_pos + 1;
        
        if (h_pos == H_TOTAL - 1) begin 
            h_pos <= 0;
            v_pos <= v_pos + 1;
            if (v_pos == V_TOTAL - 1) begin 
                v_pos <= 0;
            end
        end
    end
end



endmodule