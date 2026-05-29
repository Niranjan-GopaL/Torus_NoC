`timescale 1ns/1ps

// =============================================================================
// vc_router_outfifo.sv — PHASE 1 VC router with OUTPUT FIFOs
//
//   Same as vc_router.sv EXCEPT the 5 output depth-1 valid_ready_slice buffers
//   are replaced by fifo_sync of depth OUT_FIFO_DEPTH. fifo_sync is pin-
//   compatible (same handshake: ready_out=!full occupancy-only, registered
//   head), so it is a true drop-in. Deadlock-freedom is unaffected: in phase 1
//   it rests entirely on the tie-split routing, not on buffering or VCs, so
//   adding output buffer depth cannot create a cycle.
//
//   Port encoding (internal): N=0, S=1, E=2, W=3, L=4
// =============================================================================

module xy_route_logic (
    input  logic [7:0] data_in,
    input  logic [1:0] my_x,
    input  logic [1:0] my_y,
    output logic [2:0] out_port
);
    logic [1:0] dst_x, dst_y;
    assign dst_x = data_in[7:6];
    assign dst_y = data_in[5:4];

    localparam PORT_N = 3'd0;
    localparam PORT_S = 3'd1;
    localparam PORT_E = 3'd2;
    localparam PORT_W = 3'd3;
    localparam PORT_L = 3'd4;

    logic [1:0] fdx, fdy;
    always_comb begin
        fdx = (dst_x - my_x) & 2'b11;
        fdy = (dst_y - my_y) & 2'b11;
        if (fdx != 2'd0) begin
            if      (fdx == 2'd1) out_port = PORT_E;
            else if (fdx == 2'd3) out_port = PORT_W;
            else                  out_port = (my_x < 2'd2) ? PORT_E : PORT_W;
        end
        else if (fdy != 2'd0) begin
            if      (fdy == 2'd1) out_port = PORT_N;
            else if (fdy == 2'd3) out_port = PORT_S;
            else                  out_port = (my_y < 2'd2) ? PORT_N : PORT_S;
        end
        else
            out_port = PORT_L;
    end
endmodule


module valid_ready_slice (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  data_in,
    input  logic        valid_in,
    output logic        ready_out,
    output logic [7:0]  data_out,
    output logic        valid_out,
    input  logic        ready_in
);
    logic        data_valid;
    logic [7:0]  data_reg;
    assign ready_out = rst_n && ( !data_valid || ready_in );
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_valid <= 1'b0;
            data_reg   <= 8'h00;
        end else begin
            if (valid_in && ready_out)      data_valid <= 1'b1;
            else if (data_valid && ready_in) data_valid <= 1'b0;
            if (valid_in && ready_out)       data_reg <= data_in;
        end
    end
    assign valid_out = data_valid;
    assign data_out  = data_reg;
endmodule


module fifo_sync #(
    parameter int DEPTH      = 4,
    parameter int DATA_WIDTH = 8
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic [DATA_WIDTH-1:0]  data_in,
    input  logic                   valid_in,
    output logic                   ready_out,
    output logic [DATA_WIDTH-1:0]  data_out,
    output logic                   valid_out,
    input  logic                   ready_in
);
    localparam int PTR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH:0]    wr_ptr, rd_ptr;
    logic                  empty, full;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
                   (wr_ptr[PTR_WIDTH]      != rd_ptr[PTR_WIDTH]);

    assign ready_out = rst_n && !full;
    assign valid_out = !empty;
    assign data_out  = mem[rd_ptr[PTR_WIDTH-1:0]];

    logic do_push, do_pop;
    assign do_push = valid_in  && ready_out;
    assign do_pop  = valid_out && ready_in;

    function automatic logic [PTR_WIDTH:0] ptr_next(input logic [PTR_WIDTH:0] p);
        logic [PTR_WIDTH-1:0] addr; logic wrap;
        begin
            addr = p[PTR_WIDTH-1:0]; wrap = p[PTR_WIDTH];
            if (addr == (DEPTH-1)) begin addr = '0; wrap = ~wrap; end
            else                        addr = addr + 1'b1;
            ptr_next = {wrap, addr};
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0; rd_ptr <= '0;
        end else begin
            if (do_push) begin mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in; wr_ptr <= ptr_next(wr_ptr); end
            if (do_pop)  rd_ptr <= ptr_next(rd_ptr);
        end
    end
endmodule


module split_1to4_simple #(
    parameter int INPUT_PORT = 0
)(
    input  logic       valid_in,
    input  logic [7:0] data_in,
    output logic       ready_in,
    input  logic [1:0] my_x,
    input  logic [1:0] my_y,
    output logic [3:0] valid_out,
    output logic [7:0] data_out,
    input  logic [3:0] ready_out
);
    logic [2:0] global_port;
    logic [1:0] dest_index;

    xy_route_logic u_xy (.data_in(data_in), .my_x(my_x), .my_y(my_y), .out_port(global_port));

    always_comb begin
        valid_out  = 4'b0000;
        ready_in   = 1'b0;
        dest_index = 2'd0;
        case (INPUT_PORT)
            0: case (global_port) 1:dest_index=0;2:dest_index=1;3:dest_index=2;4:dest_index=3;default:dest_index=0; endcase
            1: case (global_port) 0:dest_index=0;2:dest_index=1;3:dest_index=2;4:dest_index=3;default:dest_index=0; endcase
            2: case (global_port) 0:dest_index=0;1:dest_index=1;3:dest_index=2;4:dest_index=3;default:dest_index=0; endcase
            3: case (global_port) 0:dest_index=0;1:dest_index=1;2:dest_index=2;4:dest_index=3;default:dest_index=0; endcase
            4: case (global_port) 0:dest_index=0;1:dest_index=1;2:dest_index=2;3:dest_index=3;default:dest_index=0; endcase
        endcase
        if (valid_in) valid_out[dest_index] = 1'b1;
        ready_in = ready_out[dest_index];
    end
    assign data_out = data_in;
endmodule


module merge_4to1_comb #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_PORTS  = 4
)(
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic [NUM_PORTS-1:0]        valid_in,
    output logic [NUM_PORTS-1:0]        ready_in,
    input  logic [DATA_WIDTH-1:0]       data_in [0:NUM_PORTS-1],
    output logic                        valid_out,
    input  logic                        ready_out,
    output logic [DATA_WIDTH-1:0]       data_out
);
    logic [NUM_PORTS-1:0]         mask, masked_req, unmasked_grant, grant;
    logic [$clog2(NUM_PORTS)-1:0] selected_port;

    assign masked_req     = valid_in & mask;
    assign unmasked_grant = valid_in & (~valid_in + 1);
    assign grant = (|masked_req) ? (masked_req & (~masked_req + 1)) : unmasked_grant;

    always_comb begin
        selected_port = '0;
        for (int i = NUM_PORTS-1; i >= 0; i--)
            if (grant[i]) selected_port = i[$clog2(NUM_PORTS)-1:0];
    end

    assign ready_in  = grant & {NUM_PORTS{ready_out}};
    assign valid_out = |grant;
    assign data_out  = data_in[selected_port];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) mask <= {NUM_PORTS{1'b1}};
        else if (valid_out && ready_out && |grant) begin
            if (|masked_req) mask <= mask & ~grant;
            else             mask <= {NUM_PORTS{1'b1}} & ~grant;
        end
    end
endmodule


module router_plane (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [1:0]  my_x,
    input  logic [1:0]  my_y,
    input  logic [4:0]  pin_valid,
    input  logic [39:0] pin_data,
    output logic [4:0]  pin_ready,
    output logic [4:0]  pout_valid,
    output logic [39:0] pout_data,
    input  logic [4:0]  pout_ready
);
    logic [7:0] s_in_data [0:4];
    genvar up;
    generate
        for (up = 0; up < 5; up = up + 1) begin : g_unpack
            assign s_in_data[up] = pin_data[up*8 +: 8];
        end
    endgenerate

    logic [3:0] split_valid [0:4];
    logic [3:0] split_ready [0:4];
    logic [7:0] split_data  [0:4];

    split_1to4_simple #(.INPUT_PORT(0)) u_split_0 (.valid_in(pin_valid[0]),.data_in(s_in_data[0]),.ready_in(pin_ready[0]),.my_x(my_x),.my_y(my_y),.valid_out(split_valid[0]),.data_out(split_data[0]),.ready_out(split_ready[0]));
    split_1to4_simple #(.INPUT_PORT(1)) u_split_1 (.valid_in(pin_valid[1]),.data_in(s_in_data[1]),.ready_in(pin_ready[1]),.my_x(my_x),.my_y(my_y),.valid_out(split_valid[1]),.data_out(split_data[1]),.ready_out(split_ready[1]));
    split_1to4_simple #(.INPUT_PORT(2)) u_split_2 (.valid_in(pin_valid[2]),.data_in(s_in_data[2]),.ready_in(pin_ready[2]),.my_x(my_x),.my_y(my_y),.valid_out(split_valid[2]),.data_out(split_data[2]),.ready_out(split_ready[2]));
    split_1to4_simple #(.INPUT_PORT(3)) u_split_3 (.valid_in(pin_valid[3]),.data_in(s_in_data[3]),.ready_in(pin_ready[3]),.my_x(my_x),.my_y(my_y),.valid_out(split_valid[3]),.data_out(split_data[3]),.ready_out(split_ready[3]));
    split_1to4_simple #(.INPUT_PORT(4)) u_split_4 (.valid_in(pin_valid[4]),.data_in(s_in_data[4]),.ready_in(pin_ready[4]),.my_x(my_x),.my_y(my_y),.valid_out(split_valid[4]),.data_out(split_data[4]),.ready_out(split_ready[4]));

    logic [7:0] merge_data  [0:4];
    logic [4:0] merge_valid;

    assign pout_valid = merge_valid;
    generate
        for (up = 0; up < 5; up = up + 1) begin : g_pack
            assign pout_data[up*8 +: 8] = merge_data[up];
        end
    endgenerate

    logic [7:0] m0_data_in [0:3]; logic [3:0] m0_valid_in, m0_ready_in;
    assign m0_data_in[0]=split_data[1]; assign m0_data_in[1]=split_data[2]; assign m0_data_in[2]=split_data[3]; assign m0_data_in[3]=split_data[4];
    assign m0_valid_in={split_valid[4][0],split_valid[3][0],split_valid[2][0],split_valid[1][0]};
    merge_4to1_comb u_merge_0 (.clk(clk),.rst_n(rst_n),.valid_in(m0_valid_in),.ready_in(m0_ready_in),.data_in(m0_data_in),.valid_out(merge_valid[0]),.ready_out(pout_ready[0]),.data_out(merge_data[0]));
    assign split_ready[1][0]=m0_ready_in[0]; assign split_ready[2][0]=m0_ready_in[1]; assign split_ready[3][0]=m0_ready_in[2]; assign split_ready[4][0]=m0_ready_in[3];

    logic [7:0] m1_data_in [0:3]; logic [3:0] m1_valid_in, m1_ready_in;
    assign m1_data_in[0]=split_data[0]; assign m1_data_in[1]=split_data[2]; assign m1_data_in[2]=split_data[3]; assign m1_data_in[3]=split_data[4];
    assign m1_valid_in={split_valid[4][1],split_valid[3][1],split_valid[2][1],split_valid[0][0]};
    merge_4to1_comb u_merge_1 (.clk(clk),.rst_n(rst_n),.valid_in(m1_valid_in),.ready_in(m1_ready_in),.data_in(m1_data_in),.valid_out(merge_valid[1]),.ready_out(pout_ready[1]),.data_out(merge_data[1]));
    assign split_ready[0][0]=m1_ready_in[0]; assign split_ready[2][1]=m1_ready_in[1]; assign split_ready[3][1]=m1_ready_in[2]; assign split_ready[4][1]=m1_ready_in[3];

    logic [7:0] m2_data_in [0:3]; logic [3:0] m2_valid_in, m2_ready_in;
    assign m2_data_in[0]=split_data[0]; assign m2_data_in[1]=split_data[1]; assign m2_data_in[2]=split_data[3]; assign m2_data_in[3]=split_data[4];
    assign m2_valid_in={split_valid[4][2],split_valid[3][2],split_valid[1][1],split_valid[0][1]};
    merge_4to1_comb u_merge_2 (.clk(clk),.rst_n(rst_n),.valid_in(m2_valid_in),.ready_in(m2_ready_in),.data_in(m2_data_in),.valid_out(merge_valid[2]),.ready_out(pout_ready[2]),.data_out(merge_data[2]));
    assign split_ready[0][1]=m2_ready_in[0]; assign split_ready[1][1]=m2_ready_in[1]; assign split_ready[3][2]=m2_ready_in[2]; assign split_ready[4][2]=m2_ready_in[3];

    logic [7:0] m3_data_in [0:3]; logic [3:0] m3_valid_in, m3_ready_in;
    assign m3_data_in[0]=split_data[0]; assign m3_data_in[1]=split_data[1]; assign m3_data_in[2]=split_data[2]; assign m3_data_in[3]=split_data[4];
    assign m3_valid_in={split_valid[4][3],split_valid[2][2],split_valid[1][2],split_valid[0][2]};
    merge_4to1_comb u_merge_3 (.clk(clk),.rst_n(rst_n),.valid_in(m3_valid_in),.ready_in(m3_ready_in),.data_in(m3_data_in),.valid_out(merge_valid[3]),.ready_out(pout_ready[3]),.data_out(merge_data[3]));
    assign split_ready[0][2]=m3_ready_in[0]; assign split_ready[1][2]=m3_ready_in[1]; assign split_ready[2][2]=m3_ready_in[2]; assign split_ready[4][3]=m3_ready_in[3];

    logic [7:0] m4_data_in [0:3]; logic [3:0] m4_valid_in, m4_ready_in;
    assign m4_data_in[0]=split_data[0]; assign m4_data_in[1]=split_data[1]; assign m4_data_in[2]=split_data[2]; assign m4_data_in[3]=split_data[3];
    assign m4_valid_in={split_valid[3][3],split_valid[2][3],split_valid[1][3],split_valid[0][3]};
    merge_4to1_comb u_merge_4 (.clk(clk),.rst_n(rst_n),.valid_in(m4_valid_in),.ready_in(m4_ready_in),.data_in(m4_data_in),.valid_out(merge_valid[4]),.ready_out(pout_ready[4]),.data_out(merge_data[4]));
    assign split_ready[0][3]=m4_ready_in[0]; assign split_ready[1][3]=m4_ready_in[1]; assign split_ready[2][3]=m4_ready_in[2]; assign split_ready[3][3]=m4_ready_in[3];
endmodule


// =============================================================================
// vc_router — VC input buffering + two-stage arbitration + OUTPUT FIFOs
// =============================================================================
module vc_router #(
    parameter int NUM_VC        = 2,
    parameter int FIFO_DEPTH    = 16,
    parameter int OUT_FIFO_DEPTH = 16
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [1:0]  my_x,
    input  logic [1:0]  my_y,

    input  logic [4:0]  in_valid,
    input  logic [7:0]  in_data_0, in_data_1, in_data_2, in_data_3, in_data_4,
    output logic [4:0]  in_ready,

    output logic [4:0]  out_valid,
    output logic [7:0]  out_data_0, out_data_1, out_data_2, out_data_3, out_data_4,
    input  logic [4:0]  out_ready
);
    localparam int VCW = (NUM_VC < 2) ? 1 : $clog2(NUM_VC);

    logic [4:0] in_valid_int, in_ready_int;
    logic [7:0] in_data_int  [4:0];
    logic [4:0] out_valid_int, out_ready_int;
    logic [7:0] out_data_int [4:0];

    always_comb begin
        in_valid_int[0]=in_valid[3]; in_valid_int[1]=in_valid[4]; in_valid_int[2]=in_valid[1];
        in_valid_int[3]=in_valid[2]; in_valid_int[4]=in_valid[0];
        in_data_int[0]=in_data_3; in_data_int[1]=in_data_4; in_data_int[2]=in_data_1;
        in_data_int[3]=in_data_2; in_data_int[4]=in_data_0;
    end
    always_comb begin
        out_valid[0]=out_valid_int[4]; out_valid[1]=out_valid_int[2]; out_valid[2]=out_valid_int[3];
        out_valid[3]=out_valid_int[0]; out_valid[4]=out_valid_int[1];
        out_data_0=out_data_int[4]; out_data_1=out_data_int[2]; out_data_2=out_data_int[3];
        out_data_3=out_data_int[0]; out_data_4=out_data_int[1];
        out_ready_int[4]=out_ready[0]; out_ready_int[2]=out_ready[1]; out_ready_int[3]=out_ready[2];
        out_ready_int[0]=out_ready[3]; out_ready_int[1]=out_ready[4];
        in_ready[3]=in_ready_int[0]; in_ready[4]=in_ready_int[1]; in_ready[1]=in_ready_int[2];
        in_ready[2]=in_ready_int[3]; in_ready[0]=in_ready_int[4];
    end

    logic [7:0]     fifo_data [0:4][0:NUM_VC-1];
    logic           fifo_vld  [0:4][0:NUM_VC-1];
    logic           fifo_rdy  [0:4][0:NUM_VC-1];
    logic           fifo_push [0:4][0:NUM_VC-1];
    logic [VCW-1:0] rr_cnt    [0:4];

    logic [4:0]  plane_pin_valid  [0:NUM_VC-1];
    logic [39:0] plane_pin_data   [0:NUM_VC-1];
    logic [4:0]  plane_pin_ready  [0:NUM_VC-1];
    logic [4:0]  plane_pout_valid [0:NUM_VC-1];
    logic [39:0] plane_pout_data  [0:NUM_VC-1];
    logic [4:0]  plane_pout_ready [0:NUM_VC-1];

    genvar gp, gv;
    generate
        for (gp = 0; gp < 5; gp = gp + 1) begin : g_port
            always_comb begin
                for (int v = 0; v < NUM_VC; v++)
                    fifo_push[gp][v] = in_valid_int[gp] && (rr_cnt[gp] == v[VCW-1:0]);
            end
            assign in_ready_int[gp] = fifo_rdy[gp][rr_cnt[gp]];

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    rr_cnt[gp] <= '0;
                else if (in_valid_int[gp] && in_ready_int[gp])
                    rr_cnt[gp] <= (rr_cnt[gp] == NUM_VC-1) ? '0 : rr_cnt[gp] + 1'b1;
            end

            for (gv = 0; gv < NUM_VC; gv = gv + 1) begin : g_vc_fifo
                fifo_sync #(.DEPTH(FIFO_DEPTH), .DATA_WIDTH(8)) u_fifo (
                    .clk(clk), .rst_n(rst_n),
                    .data_in (in_data_int[gp]),
                    .valid_in(fifo_push[gp][gv]),
                    .ready_out(fifo_rdy[gp][gv]),
                    .data_out (fifo_data[gp][gv]),
                    .valid_out(fifo_vld[gp][gv]),
                    .ready_in (plane_pin_ready[gv][gp])
                );
                assign plane_pin_valid[gv][gp]        = fifo_vld[gp][gv];
                assign plane_pin_data [gv][gp*8 +: 8] = fifo_data[gp][gv];
            end
        end
    endgenerate

    generate
        for (gv = 0; gv < NUM_VC; gv = gv + 1) begin : g_plane
            router_plane u_plane (
                .clk(clk), .rst_n(rst_n), .my_x(my_x), .my_y(my_y),
                .pin_valid (plane_pin_valid [gv]),
                .pin_data  (plane_pin_data  [gv]),
                .pin_ready (plane_pin_ready [gv]),
                .pout_valid(plane_pout_valid[gv]),
                .pout_data (plane_pout_data [gv]),
                .pout_ready(plane_pout_ready[gv])
            );
        end
    endgenerate

    logic [7:0] merge_to_out_data  [0:4];
    logic [4:0] merge_to_out_valid;
    logic [4:0] out_to_merge_ready;

    genvar gd, gvj;
    generate
        for (gd = 0; gd < 5; gd = gd + 1) begin : g_stage2
            logic [NUM_VC-1:0] s2_valid;
            logic [NUM_VC-1:0] s2_ready;
            logic [7:0]        s2_data [0:NUM_VC-1];

            for (gvj = 0; gvj < NUM_VC; gvj = gvj + 1) begin : g_gather
                assign s2_valid[gvj]             = plane_pout_valid[gvj][gd];
                assign s2_data [gvj]             = plane_pout_data [gvj][gd*8 +: 8];
                assign plane_pout_ready[gvj][gd] = s2_ready[gvj];
            end

            merge_4to1_comb #(.DATA_WIDTH(8), .NUM_PORTS(NUM_VC)) u_stage2 (
                .clk(clk), .rst_n(rst_n),
                .valid_in (s2_valid),
                .ready_in (s2_ready),
                .data_in  (s2_data),
                .valid_out(merge_to_out_valid[gd]),
                .ready_out(out_to_merge_ready[gd]),
                .data_out (merge_to_out_data[gd])
            );
        end
    endgenerate

    // ---- OUTPUT FIFOs (was depth-1 valid_ready_slice) ----
    genvar go;
    generate
        for (go = 0; go < 5; go = go + 1) begin : g_output_fifo
            fifo_sync #(.DEPTH(OUT_FIFO_DEPTH), .DATA_WIDTH(8)) u_output_fifo (
                .clk(clk), .rst_n(rst_n),
                .data_in  (merge_to_out_data[go]),
                .valid_in (merge_to_out_valid[go]),
                .ready_out(out_to_merge_ready[go]),
                .data_out (out_data_int[go]),
                .valid_out(out_valid_int[go]),
                .ready_in (out_ready_int[go])
            );
        end
    endgenerate
endmodule


module torus_router_5x5 #(
    parameter int CURR_X         = 0,
    parameter int CURR_Y         = 0,
    parameter int NUM_VC         = 4,
    parameter int FIFO_DEPTH     = 16,
    parameter int OUT_FIFO_DEPTH = 32
)(
    input  logic            clk,
    input  logic            rst_n,
    input  logic [4:0]      in_vld,
    output logic [4:0]      in_rdy,
    input  logic [4:0][7:0] in_data,
    output logic [4:0]      out_vld,
    input  logic [4:0]      out_rdy,
    output logic [4:0][7:0] out_data
);
    vc_router #(.NUM_VC(NUM_VC), .FIFO_DEPTH(FIFO_DEPTH), .OUT_FIFO_DEPTH(OUT_FIFO_DEPTH)) u_router (
        .clk(clk), .rst_n(rst_n), .my_x(CURR_X[1:0]), .my_y(CURR_Y[1:0]),
        .in_valid (in_vld), .in_ready(in_rdy),
        .in_data_0(in_data[0]), .in_data_1(in_data[1]), .in_data_2(in_data[2]),
        .in_data_3(in_data[3]), .in_data_4(in_data[4]),
        .out_valid(out_vld), .out_ready(out_rdy),
        .out_data_0(out_data[0]), .out_data_1(out_data[1]), .out_data_2(out_data[2]),
        .out_data_3(out_data[3]), .out_data_4(out_data[4])
    );
endmodule