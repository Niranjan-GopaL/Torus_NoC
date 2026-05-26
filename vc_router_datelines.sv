`timescale 1ns/1ps

// =============================================================================
// vc_router_dateline.sv — PHASE 2 virtual-channel router (dateline, NUM_VC=2)
//
// GOAL
//   Deadlock-free torus routing whose safety comes from the VC discipline
//   (a dateline), NOT from a 4x4-specific coordinate trick. Routing is now
//   true ALWAYS-POSITIVE shortest path: for the distance-2 tie it always goes
//   East/North, which on its own forms a cyclic channel dependency around each
//   ring (the classic torus deadlock). Two VCs + a dateline break that cycle.
//
// THE MEMORYLESS DATELINE ("will-cross")
//   Classic dateline carries a "have I crossed?" history bit on the wire.
//   Instead we use "WILL I cross?": VC = 1 iff the remaining positive path
//   from the current node to the destination still traverses the ring's wrap
//   link (the dateline, node 3 -> 0 for +X; node 3 -> 0 for +Y). This is a
//   pure function of (node, destination), so every router recomputes it
//   locally — nothing rides on the wire. The channel-dependency graph splits
//   into VC1 (pre-dateline) and VC0 (post-dateline) layers with edges only
//   VC1->VC1, VC1->VC0 (at the dateline), VC0->VC0 — acyclic => deadlock-free.
//
// INTERFACE UNCHANGED
//   8-bit flit, single-bit ready per link. The receiver computes the incoming
//   flit's VC and reports that VC's FIFO readiness as the single ready bit, and
//   demuxes the flit into that VC FIFO. So torus_4x4 and the testbench are
//   byte-for-byte identical. (Negative-direction hops are single-hop on a
//   size-4 ring, hence never chain, so their VC is irrelevant to safety.)
//
// BUFFERS
//   Per input port: NUM_VC FIFOs (your proven fifo_sync). No output slices in
//   this phase: the only buffers are the per-VC input FIFOs, so the CDG is
//   exactly the proven per-VC-channel graph. (For synthesis timing you would
//   later add VC-aware output buffering; omitted here to keep the proof clean.)
//
//   NUM_VC is parameterized but the dateline uses exactly 2 VCs; set NUM_VC=2.
//   Port encoding (internal): N=0, S=1, E=2, W=3, L=4
// =============================================================================


// =============================================================================
// fifo_sync — synchronous FIFO (UNCHANGED, occupancy-only ready)
// =============================================================================
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
    logic empty, full;

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
        if (!rst_n) begin wr_ptr <= '0; rd_ptr <= '0; end
        else begin
            if (do_push) begin mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in; wr_ptr <= ptr_next(wr_ptr); end
            if (do_pop)  rd_ptr <= ptr_next(rd_ptr);
        end
    end
endmodule


// =============================================================================
// merge_4to1_comb — masked round-robin merge (UNCHANGED). Reused here at
//   width NUM_PORTS = 5*NUM_VC (one merge per output direction, gathering
//   every (input port, VC) stream). Requires NUM_PORTS >= 2.
// =============================================================================
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


// =============================================================================
// vc_router — dateline VC router
// =============================================================================
module vc_router #(
    parameter int NUM_VC     = 2,   // dateline uses 2
    parameter int FIFO_DEPTH = 4
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

    localparam logic [2:0] PORT_N = 3'd0;
    localparam logic [2:0] PORT_S = 3'd1;
    localparam logic [2:0] PORT_E = 3'd2;
    localparam logic [2:0] PORT_W = 3'd3;
    localparam logic [2:0] PORT_L = 3'd4;

    // ---- routing: ALWAYS-POSITIVE shortest (dimension order X then Y) ----
    // (To A/B against the deadlock-free-without-VC tie-split, replace the two
    //  "else PORT_E"/"else PORT_N" lines with the (my<2)?E:W form.)
    function automatic logic [2:0] route_dir(
        input logic [1:0] mx, input logic [1:0] myy,
        input logic [1:0] dx, input logic [1:0] dyy);
        logic [1:0] fdx, fdy;
        begin
            fdx = (dx - mx) & 2'b11;
            fdy = (dyy - myy) & 2'b11;
            if (fdx != 2'd0)      route_dir = (fdx == 2'd3) ? PORT_W : PORT_E;
            else if (fdy != 2'd0) route_dir = (fdy == 2'd3) ? PORT_S : PORT_N;
            else                  route_dir = PORT_L;
        end
    endfunction

    // ---- "will-cross" dateline test for a POSITIVE hop from node c to dst ----
    //   remaining positive path c -> dst crosses the wrap link (3 -> 0) iff
    //   c + ((dst-c) mod 4) >= 4.  Returns the VC (1 = will cross, 0 = won't).
    function automatic logic crosses_pos(input logic [1:0] c, input logic [1:0] dst);
        logic [1:0] fd; logic [3:0] sum;
        begin
            fd  = (dst - c) & 2'b11;
            sum = {2'b00, c} + {2'b00, fd};
            crosses_pos = (sum >= 4'd4);
        end
    endfunction

    // ---- port remap: testbench [L,E,W,N,S] <-> internal [N,S,E,W,L] ----
    logic [4:0] in_valid_int, in_ready_int;
    logic [7:0] in_data_int  [0:4];
    logic [4:0] out_valid_int, out_ready_int;
    logic [7:0] out_data_int [0:4];

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

    // ---- per-input-port VC assignment (memoryless dateline) ----
    // in_vc[p] = the VC of the link feeding internal input port p, computed
    // from this node's coords, the input direction (which fixes the sender),
    // and the flit's destination.
    logic [VCW-1:0] in_vc [0:4];
    always_comb begin
        for (int p = 0; p < 5; p++) begin
            logic [1:0] dx, dy;
            logic [2:0] fdir;
            dx = in_data_int[p][7:6];
            dy = in_data_int[p][5:4];
            in_vc[p] = '0;
            case (p)
                0: in_vc[p] = (my_y == 2'd3);                    // N input: south-bound, sender=my_y+1, dateline iff sender==0
                1: in_vc[p] = crosses_pos(my_y - 2'd1, dy);      // S input: north-bound, sender=my_y-1 (positive)
                2: in_vc[p] = (my_x == 2'd3);                    // E input: west-bound, sender=my_x+1, dateline iff sender==0
                3: in_vc[p] = crosses_pos(my_x - 2'd1, dx);      // W input: east-bound, sender=my_x-1 (positive)
                4: begin                                         // L input: fresh injection, VC of first hop from here
                    fdir = route_dir(my_x, my_y, dx, dy);
                    case (fdir)
                        PORT_E: in_vc[p] = crosses_pos(my_x, dx);
                        PORT_W: in_vc[p] = (my_x == 2'd0);
                        PORT_N: in_vc[p] = crosses_pos(my_y, dy);
                        PORT_S: in_vc[p] = (my_y == 2'd0);
                        default: in_vc[p] = '0;
                    endcase
                end
            endcase
        end
    end

    // ---- per (port, vc) FIFOs ----
    logic [7:0]     fifo_data [0:4][0:NUM_VC-1];
    logic           fifo_vld  [0:4][0:NUM_VC-1];
    logic           fifo_rdy  [0:4][0:NUM_VC-1];   // occupancy-only ready_out
    logic           fifo_push [0:4][0:NUM_VC-1];
    logic           fifo_pop  [0:4][0:NUM_VC-1];   // ready_in to FIFO (granted)
    logic [2:0]     hdir      [0:4][0:NUM_VC-1];   // routing of each FIFO head

    genvar gp, gv;
    generate
        for (gp = 0; gp < 5; gp = gp + 1) begin : g_port
            // demux incoming flit into the dateline-selected VC; single ready
            always_comb begin
                for (int v = 0; v < NUM_VC; v++)
                    fifo_push[gp][v] = in_valid_int[gp] && (in_vc[gp] == v[VCW-1:0]);
            end
            assign in_ready_int[gp] = fifo_rdy[gp][in_vc[gp]];

            for (gv = 0; gv < NUM_VC; gv = gv + 1) begin : g_vc
                fifo_sync #(.DEPTH(FIFO_DEPTH), .DATA_WIDTH(8)) u_fifo (
                    .clk(clk), .rst_n(rst_n),
                    .data_in (in_data_int[gp]),
                    .valid_in(fifo_push[gp][gv]),
                    .ready_out(fifo_rdy[gp][gv]),
                    .data_out (fifo_data[gp][gv]),
                    .valid_out(fifo_vld[gp][gv]),
                    .ready_in (fifo_pop[gp][gv])
                );
                assign hdir[gp][gv] = route_dir(my_x, my_y,
                                                fifo_data[gp][gv][7:6],
                                                fifo_data[gp][gv][5:4]);
            end
        end
    endgenerate

    // ---- one merge per output direction, gathering all (port,vc) streams ----
    localparam int MW = 5*NUM_VC;     // merge width

    // ready from each merge slot, collected back to FIFOs
    logic [MW-1:0] mready [0:4];      // [dir][slot]

    genvar gd, gpp, gvv;
    generate
        for (gd = 0; gd < 5; gd = gd + 1) begin : g_merge
            logic [MW-1:0] mvalid;
            logic [7:0]    mdata [0:MW-1];

            for (gpp = 0; gpp < 5; gpp = gpp + 1) begin : g_p
                for (gvv = 0; gvv < NUM_VC; gvv = gvv + 1) begin : g_v
                    localparam int SLOT = gpp*NUM_VC + gvv;
                    assign mvalid[SLOT] = fifo_vld[gpp][gvv] && (hdir[gpp][gvv] == gd[2:0]);
                    assign mdata [SLOT] = fifo_data[gpp][gvv];
                end
            end

            merge_4to1_comb #(.DATA_WIDTH(8), .NUM_PORTS(MW)) u_merge (
                .clk(clk), .rst_n(rst_n),
                .valid_in (mvalid),
                .ready_in (mready[gd]),
                .data_in  (mdata),
                .valid_out(out_valid_int[gd]),
                .ready_out(out_ready_int[gd]),       // single-bit link/local ready
                .data_out (out_data_int[gd])
            );
        end
    endgenerate

    // ---- collect grants back to each FIFO (it requests exactly one dir) ----
    generate
        for (gpp = 0; gpp < 5; gpp = gpp + 1) begin : g_pop_p
            for (gvv = 0; gvv < NUM_VC; gvv = gvv + 1) begin : g_pop_v
                localparam int SLOT = gpp*NUM_VC + gvv;
                always_comb begin
                    fifo_pop[gpp][gvv] = 1'b0;
                    for (int d = 0; d < 5; d++)
                        fifo_pop[gpp][gvv] = fifo_pop[gpp][gvv] | mready[d][SLOT];
                end
            end
        end
    endgenerate
endmodule


// =============================================================================
// torus_router_5x5 — wrapper (UNCHANGED interface; forwards NUM_VC/DEPTH)
// =============================================================================
module torus_router_5x5 #(
    parameter int CURR_X     = 0,
    parameter int CURR_Y     = 0,
    parameter int NUM_VC     = 4,
    parameter int FIFO_DEPTH = 16
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
    vc_router #(.NUM_VC(NUM_VC), .FIFO_DEPTH(FIFO_DEPTH)) u_router (
        .clk(clk), .rst_n(rst_n), .my_x(CURR_X[1:0]), .my_y(CURR_Y[1:0]),
        .in_valid (in_vld), .in_ready(in_rdy),
        .in_data_0(in_data[0]), .in_data_1(in_data[1]), .in_data_2(in_data[2]),
        .in_data_3(in_data[3]), .in_data_4(in_data[4]),
        .out_valid(out_vld), .out_ready(out_rdy),
        .out_data_0(out_data[0]), .out_data_1(out_data[1]), .out_data_2(out_data[2]),
        .out_data_3(out_data[3]), .out_data_4(out_data[4])
    );
endmodule