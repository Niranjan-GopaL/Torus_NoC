`timescale 1ns/1ps

// =============================================================================
// router_fifo_v2.sv — 5-port router: per-VC FIFOs between split and merge
//
// STRUCTURAL CHANGES vs router_fifo.sv (router_with_fifo):
//
//   CHANGE 1 — Input stage is now a depth-1 valid_ready_slice (was fifo_sync).
//              The slice still provides the cut-through register that decouples
//              the incoming link from the routing logic, but without deep
//              buffering at the input.
//
//   CHANGE 2 — 20 independent Virtual-Channel FIFOs are inserted between
//              every split output and its matching merge input.
//              One FIFO per (input-port, output-port) pair eliminates
//              Head-of-Line blocking: a stalled output port cannot block
//              flits that are headed for any other output port.
//
// Full pipeline per flit:
//   external_in
//     ──► valid_ready_slice  (input, depth 1)          [CHANGE 1]
//     ──► split_1to4_simple  (XY/OE route decode)
//     ──► fifo_sync          (VC FIFO, FIFO_DEPTH)     [CHANGE 2]
//     ──► merge_4to1_comb    (round-robin arbitration)
//     ──► valid_ready_slice  (output, depth 1, unchanged)
//     ──► external_out
//
// VC FIFO count: 5 input-ports × 4 output-ports = 20 FIFOs per router.
//
// VC FIFO index  vc[split_idx][out_idx]:
//   split_idx  0=N  1=S  2=E  3=W  4=L    (internal port numbering)
//   out_idx    0..3 = the four egress directions from that split
//              (derived from split_1to4_simple INPUT_PORT case tables)
//
// Split output-index → egress direction:
//   Split 0 (IN=N):  [0]=S  [1]=E  [2]=W  [3]=L
//   Split 1 (IN=S):  [0]=N  [1]=E  [2]=W  [3]=L
//   Split 2 (IN=E):  [0]=N  [1]=S  [2]=W  [3]=L
//   Split 3 (IN=W):  [0]=N  [1]=S  [2]=E  [3]=L
//   Split 4 (IN=L):  [0]=N  [1]=S  [2]=E  [3]=W
//
// VC FIFO → Merge mapping (verified against all five tables above):
//   Merge 0 (N out):  vc[1][0]  vc[2][0]  vc[3][0]  vc[4][0]
//   Merge 1 (S out):  vc[0][0]  vc[2][1]  vc[3][1]  vc[4][1]
//   Merge 2 (E out):  vc[0][1]  vc[1][1]  vc[3][2]  vc[4][2]
//   Merge 3 (W out):  vc[0][2]  vc[1][2]  vc[2][2]  vc[4][3]
//   Merge 4 (L out):  vc[0][3]  vc[1][3]  vc[2][3]  vc[3][3]
//
// External port order (matches testbench / torus_4x4 wrapper):
//   [0]=LOCAL  [1]=EAST  [2]=WEST  [3]=NORTH  [4]=SOUTH
// Internal port order: N=0  S=1  E=2  W=3  L=4
// =============================================================================


// =============================================================================
// 1. xy_route_logic   (UNCHANGED)
// =============================================================================
module xy_route_logic (
    input  logic [7:0] data_in,
    input  logic [1:0] my_x,
    input  logic [1:0] my_y,
    output logic [2:0] out_port
);
    logic [1:0] dst_x;
    logic [1:0] dst_y;

    assign dst_x = data_in[7:6];
    assign dst_y = data_in[5:4];

    localparam PORT_N = 3'd0;
    localparam PORT_S = 3'd1;
    localparam PORT_E = 3'd2;
    localparam PORT_W = 3'd3;
    localparam PORT_L = 3'd4;

    // Odd-Even turn model (Glass & Ni 1993)
    always_comb begin
        if ((dst_x == my_x) && (dst_y == my_y))
            out_port = PORT_L;
        else if (dst_x == my_x)
            out_port = (dst_y > my_y) ? PORT_N : PORT_S;
        else if (dst_y == my_y)
            out_port = (dst_x > my_x) ? PORT_E : PORT_W;
        else if (dst_x > my_x) begin
            if (my_x[0] == 1'b0)
                out_port = PORT_E;
            else
                out_port = (dst_y > my_y) ? PORT_N : PORT_S;
        end else begin
            if (my_x[0] == 1'b0)
                out_port = (dst_y > my_y) ? PORT_N : PORT_S;
            else
                out_port = PORT_W;
        end
    end
endmodule


// =============================================================================
// 2. valid_ready_slice   (UNCHANGED)
// =============================================================================
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
    logic       data_valid;
    logic [7:0] data_reg;

    assign ready_out = rst_n && (!data_valid || ready_in);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_valid <= 1'b0;
            data_reg   <= 8'h00;
        end else begin
            if (valid_in && ready_out)
                data_valid <= 1'b1;
            else if (data_valid && ready_in)
                data_valid <= 1'b0;
            if (valid_in && ready_out)
                data_reg <= data_in;
        end
    end

    assign valid_out = data_valid;
    assign data_out  = data_reg;
endmodule


// =============================================================================
// 2b. fifo_sync   (UNCHANGED)
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
    logic [PTR_WIDTH:0]    wr_ptr;
    logic [PTR_WIDTH:0]    rd_ptr;
    logic empty, full;

    assign empty    = (wr_ptr == rd_ptr);
    assign full     = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
                      (wr_ptr[PTR_WIDTH]      != rd_ptr[PTR_WIDTH]);
    assign ready_out = rst_n && !full;
    assign valid_out = !empty;
    assign data_out  = mem[rd_ptr[PTR_WIDTH-1:0]];

    logic do_push, do_pop;
    assign do_push = valid_in  && ready_out;
    assign do_pop  = valid_out && ready_in;

    function automatic logic [PTR_WIDTH:0] ptr_next(input logic [PTR_WIDTH:0] p);
        logic [PTR_WIDTH-1:0] addr;
        logic                 wrap;
        begin
            addr = p[PTR_WIDTH-1:0];
            wrap = p[PTR_WIDTH];
            if (addr == PTR_WIDTH'(DEPTH-1)) begin
                addr = '0;
                wrap = ~wrap;
            end else begin
                addr = addr + 1'b1;
            end
            ptr_next = {wrap, addr};
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (do_push) begin
                mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in;
                wr_ptr                     <= ptr_next(wr_ptr);
            end
            if (do_pop)
                rd_ptr <= ptr_next(rd_ptr);
        end
    end
endmodule


// =============================================================================
// 3. split_1to4_simple   (UNCHANGED)
// =============================================================================
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

    xy_route_logic u_xy (
        .data_in  (data_in),
        .my_x     (my_x),
        .my_y     (my_y),
        .out_port (global_port)
    );

    always_comb begin
        valid_out  = 4'b0000;
        ready_in   = 1'b0;
        dest_index = 2'd0;

        case (INPUT_PORT)
            0: begin  // N in: can go S(0) E(1) W(2) L(3)
                case (global_port)
                    1: dest_index = 0;
                    2: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end
            1: begin  // S in: can go N(0) E(1) W(2) L(3)
                case (global_port)
                    0: dest_index = 0;
                    2: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end
            2: begin  // E in: can go N(0) S(1) W(2) L(3)
                case (global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end
            3: begin  // W in: can go N(0) S(1) E(2) L(3)
                case (global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    2: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end
            4: begin  // L in: can go N(0) S(1) E(2) W(3)
                case (global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    2: dest_index = 2;
                    3: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end
            default: dest_index = 0;
        endcase

        if (valid_in)
            valid_out[dest_index] = 1'b1;
        ready_in = ready_out[dest_index];
    end

    assign data_out = data_in;
endmodule


// =============================================================================
// 4. merge_4to1_comb   (UNCHANGED)
// =============================================================================
module merge_4to1_comb #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_PORTS  = 4
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [NUM_PORTS-1:0]  valid_in,
    output logic [NUM_PORTS-1:0]  ready_in,
    input  logic [DATA_WIDTH-1:0] data_in [0:NUM_PORTS-1],
    output logic                  valid_out,
    input  logic                  ready_out,
    output logic [DATA_WIDTH-1:0] data_out
);
    logic [NUM_PORTS-1:0]         mask;
    logic [NUM_PORTS-1:0]         masked_req;
    logic [NUM_PORTS-1:0]         unmasked_grant;
    logic [NUM_PORTS-1:0]         grant;
    logic [$clog2(NUM_PORTS)-1:0] selected_port;

    assign masked_req     = valid_in & mask;
    assign unmasked_grant = valid_in & (~valid_in + 1);
    assign grant          = (|masked_req) ? (masked_req & (~masked_req + 1))
                                           : unmasked_grant;

    always_comb begin
        selected_port = '0;
        for (int i = NUM_PORTS-1; i >= 0; i--)
            if (grant[i]) selected_port = i[$clog2(NUM_PORTS)-1:0];
    end

    assign ready_in  = grant & {NUM_PORTS{ready_out}};
    assign valid_out = |grant;
    assign data_out  = data_in[selected_port];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask <= {NUM_PORTS{1'b1}};
        end else if (valid_out && ready_out && |grant) begin
            if (|masked_req)
                mask <= mask & ~grant;
            else
                mask <= {NUM_PORTS{1'b1}} & ~grant;
        end
    end
endmodule


// =============================================================================
// 5. router_fifo_v2 — NEW: per-VC FIFO between every split output and merge
//
// Two differences from router_with_fifo (router_fifo.sv):
//
//   Input stage : valid_ready_slice  (depth 1) instead of fifo_sync.
//
//   VC FIFOs    : 20 fifo_sync instances form the vc[split_idx][out_idx]
//                 array. They decouple each egress channel so that backpressure
//                 on one output port does NOT stall flits queued for other
//                 output ports (no HOL blocking).
//                 Each FIFO upstream side ties directly to one split output;
//                 the downstream side feeds the corresponding merge input.
// =============================================================================
module router_fifo_v2 #(
    parameter int FIFO_DEPTH = 4
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic [1:0]  my_x,
    input  logic [1:0]  my_y,

    // External ports — order: [0]=LOCAL [1]=EAST [2]=WEST [3]=NORTH [4]=SOUTH
    input  logic [4:0]  in_valid,
    input  logic [7:0]  in_data_0,   // LOCAL
    input  logic [7:0]  in_data_1,   // EAST
    input  logic [7:0]  in_data_2,   // WEST
    input  logic [7:0]  in_data_3,   // NORTH
    input  logic [7:0]  in_data_4,   // SOUTH
    output logic [4:0]  in_ready,

    output logic [4:0]  out_valid,
    output logic [7:0]  out_data_0,  // LOCAL
    output logic [7:0]  out_data_1,  // EAST
    output logic [7:0]  out_data_2,  // WEST
    output logic [7:0]  out_data_3,  // NORTH
    output logic [7:0]  out_data_4,  // SOUTH
    input  logic [4:0]  out_ready
);

    // =========================================================================
    // Port remap: external [L,E,W,N,S] <-> internal [N=0,S=1,E=2,W=3,L=4]
    // Identical to router_with_fifo.
    // =========================================================================
    logic [4:0] in_valid_int;
    logic [4:0] in_ready_int;
    logic [7:0] in_data_int  [4:0];

    logic [4:0] out_valid_int;
    logic [4:0] out_ready_int;
    logic [7:0] out_data_int [4:0];

    always_comb begin
        in_valid_int[0] = in_valid[3];   // PORT_N <- testbench NORTH
        in_valid_int[1] = in_valid[4];   // PORT_S <- testbench SOUTH
        in_valid_int[2] = in_valid[1];   // PORT_E <- testbench EAST
        in_valid_int[3] = in_valid[2];   // PORT_W <- testbench WEST
        in_valid_int[4] = in_valid[0];   // PORT_L <- testbench LOCAL

        in_data_int[0] = in_data_3;      // NORTH
        in_data_int[1] = in_data_4;      // SOUTH
        in_data_int[2] = in_data_1;      // EAST
        in_data_int[3] = in_data_2;      // WEST
        in_data_int[4] = in_data_0;      // LOCAL
    end

    always_comb begin
        out_valid[0]     = out_valid_int[4];   // LOCAL <- PORT_L
        out_valid[1]     = out_valid_int[2];   // EAST  <- PORT_E
        out_valid[2]     = out_valid_int[3];   // WEST  <- PORT_W
        out_valid[3]     = out_valid_int[0];   // NORTH <- PORT_N
        out_valid[4]     = out_valid_int[1];   // SOUTH <- PORT_S

        out_data_0       = out_data_int[4];
        out_data_1       = out_data_int[2];
        out_data_2       = out_data_int[3];
        out_data_3       = out_data_int[0];
        out_data_4       = out_data_int[1];

        out_ready_int[4] = out_ready[0];
        out_ready_int[2] = out_ready[1];
        out_ready_int[3] = out_ready[2];
        out_ready_int[0] = out_ready[3];
        out_ready_int[1] = out_ready[4];

        in_ready[3]      = in_ready_int[0];
        in_ready[4]      = in_ready_int[1];
        in_ready[1]      = in_ready_int[2];
        in_ready[2]      = in_ready_int[3];
        in_ready[0]      = in_ready_int[4];
    end

    // =========================================================================
    // Internal signal declarations
    // =========================================================================

    // ── Stage 1: input slice → split ──
    logic [7:0] slice_to_split_data  [4:0];
    logic [4:0] slice_to_split_valid;
    logic [4:0] split_to_slice_ready;

    // ── Stage 2: split → VC FIFO upstream ──
    // split_valid[i][j] : split i asserts valid on output channel j
    // split_ready[i][j] : VC FIFO[i][j].ready_out feeds back to split
    // split_data[i]     : all output channels of split i share one data bus
    logic [3:0] split_valid [4:0];
    logic [3:0] split_ready [4:0];   // driven by vc_fifo.ready_out (generate)
    logic [7:0] split_data  [4:0];

    // ── Stage 3: VC FIFO downstream → merge ──
    // vc_data[i][j]  : data output of VC FIFO[i][j]
    // vc_valid[i][j] : valid output of VC FIFO[i][j]
    // vc_ready[i][j] : ready input of VC FIFO[i][j], driven in merge section
    logic [7:0] vc_data  [4:0][3:0];
    logic [3:0] vc_valid [4:0];      // [i][j] = bit j of vc_valid[i]
    logic [3:0] vc_ready [4:0];      // [i][j] driven by merge ready_in

    // ── Stage 4: merge → output slice ──
    logic [7:0] merge_to_slice_data  [4:0];
    logic [4:0] merge_to_slice_valid;
    logic [4:0] slice_to_merge_ready;

    // =========================================================================
    // INPUT SLICES (5) — depth-1 valid_ready_slice
    // CHANGE 1: was fifo_sync #(.DEPTH(FIFO_DEPTH))
    // =========================================================================
    genvar gi;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : g_input_slice
            valid_ready_slice u_input_slice (
                .clk       (clk),
                .rst_n     (rst_n),
                .data_in   (in_data_int[gi]),
                .valid_in  (in_valid_int[gi]),
                .ready_out (in_ready_int[gi]),
                .data_out  (slice_to_split_data[gi]),
                .valid_out (slice_to_split_valid[gi]),
                .ready_in  (split_to_slice_ready[gi])
            );
        end
    endgenerate

    // =========================================================================
    // SPLITS (5) — unchanged
    // =========================================================================
    split_1to4_simple #(.INPUT_PORT(0)) u_split_0 (
        .valid_in  (slice_to_split_valid[0]),
        .data_in   (slice_to_split_data[0]),
        .ready_in  (split_to_slice_ready[0]),
        .my_x      (my_x), .my_y (my_y),
        .valid_out (split_valid[0]),
        .data_out  (split_data[0]),
        .ready_out (split_ready[0])
    );

    split_1to4_simple #(.INPUT_PORT(1)) u_split_1 (
        .valid_in  (slice_to_split_valid[1]),
        .data_in   (slice_to_split_data[1]),
        .ready_in  (split_to_slice_ready[1]),
        .my_x      (my_x), .my_y (my_y),
        .valid_out (split_valid[1]),
        .data_out  (split_data[1]),
        .ready_out (split_ready[1])
    );

    split_1to4_simple #(.INPUT_PORT(2)) u_split_2 (
        .valid_in  (slice_to_split_valid[2]),
        .data_in   (slice_to_split_data[2]),
        .ready_in  (split_to_slice_ready[2]),
        .my_x      (my_x), .my_y (my_y),
        .valid_out (split_valid[2]),
        .data_out  (split_data[2]),
        .ready_out (split_ready[2])
    );

    split_1to4_simple #(.INPUT_PORT(3)) u_split_3 (
        .valid_in  (slice_to_split_valid[3]),
        .data_in   (slice_to_split_data[3]),
        .ready_in  (split_to_slice_ready[3]),
        .my_x      (my_x), .my_y (my_y),
        .valid_out (split_valid[3]),
        .data_out  (split_data[3]),
        .ready_out (split_ready[3])
    );

    split_1to4_simple #(.INPUT_PORT(4)) u_split_4 (
        .valid_in  (slice_to_split_valid[4]),
        .data_in   (slice_to_split_data[4]),
        .ready_in  (split_to_slice_ready[4]),
        .my_x      (my_x), .my_y (my_y),
        .valid_out (split_valid[4]),
        .data_out  (split_data[4]),
        .ready_out (split_ready[4])
    );

    // =========================================================================
    // VC FIFOs (20) — CHANGE 2: new stage between split and merge
    //
    // generate loop: g_vc_split[gs].g_vc_out[gj].u_vc_fifo
    //
    //   Upstream side  (from split gs, output channel gj):
    //     data_in   = split_data[gs]       (data bus shared across all outputs)
    //     valid_in  = split_valid[gs][gj]
    //     ready_out → split_ready[gs][gj]  (backpressures the split)
    //
    //   Downstream side (to the merge that serves the egress direction for [gs][gj]):
    //     data_out  → vc_data[gs][gj]
    //     valid_out → vc_valid[gs][gj]
    //     ready_in  ← vc_ready[gs][gj]    (driven by merge.ready_in below)
    // =========================================================================
    genvar gs, gj;
    generate
        for (gs = 0; gs < 5; gs = gs + 1) begin : g_vc_split
            for (gj = 0; gj < 4; gj = gj + 1) begin : g_vc_out
                fifo_sync #(
                    .DEPTH      (FIFO_DEPTH),
                    .DATA_WIDTH (8)
                ) u_vc_fifo (
                    .clk       (clk),
                    .rst_n     (rst_n),
                    // upstream: from split
                    .data_in   (split_data [gs]),
                    .valid_in  (split_valid[gs][gj]),
                    .ready_out (split_ready[gs][gj]),
                    // downstream: to merge
                    .data_out  (vc_data [gs][gj]),
                    .valid_out (vc_valid[gs][gj]),
                    .ready_in  (vc_ready[gs][gj])
                );
            end
        end
    endgenerate

    // =========================================================================
    // MERGES (5) — sourced from VC FIFO outputs (was split outputs directly)
    //
    // Convention: merge input port k corresponds to vc[split_i][out_j] where
    //   k==0 → first source listed, k==3 → last source listed.
    // =========================================================================

    // ── MERGE 0 (OUTPUT N, internal idx 0) ──
    // Sources: S→N  vc[1][0]  |  E→N  vc[2][0]  |  W→N  vc[3][0]  |  L→N  vc[4][0]
    logic [7:0] m0_data_in [0:3];
    logic [3:0] m0_valid_in;
    logic [3:0] m0_ready_in;

    assign m0_data_in[0] = vc_data[1][0];
    assign m0_data_in[1] = vc_data[2][0];
    assign m0_data_in[2] = vc_data[3][0];
    assign m0_data_in[3] = vc_data[4][0];

    assign m0_valid_in[0] = vc_valid[1][0];
    assign m0_valid_in[1] = vc_valid[2][0];
    assign m0_valid_in[2] = vc_valid[3][0];
    assign m0_valid_in[3] = vc_valid[4][0];

    merge_4to1_comb u_merge_0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (m0_valid_in),
        .ready_in  (m0_ready_in),
        .data_in   (m0_data_in),
        .valid_out (merge_to_slice_valid[0]),
        .ready_out (slice_to_merge_ready[0]),
        .data_out  (merge_to_slice_data[0])
    );

    assign vc_ready[1][0] = m0_ready_in[0];
    assign vc_ready[2][0] = m0_ready_in[1];
    assign vc_ready[3][0] = m0_ready_in[2];
    assign vc_ready[4][0] = m0_ready_in[3];

    // ── MERGE 1 (OUTPUT S, internal idx 1) ──
    // Sources: N→S  vc[0][0]  |  E→S  vc[2][1]  |  W→S  vc[3][1]  |  L→S  vc[4][1]
    logic [7:0] m1_data_in [0:3];
    logic [3:0] m1_valid_in;
    logic [3:0] m1_ready_in;

    assign m1_data_in[0] = vc_data[0][0];
    assign m1_data_in[1] = vc_data[2][1];
    assign m1_data_in[2] = vc_data[3][1];
    assign m1_data_in[3] = vc_data[4][1];

    assign m1_valid_in[0] = vc_valid[0][0];
    assign m1_valid_in[1] = vc_valid[2][1];
    assign m1_valid_in[2] = vc_valid[3][1];
    assign m1_valid_in[3] = vc_valid[4][1];

    merge_4to1_comb u_merge_1 (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (m1_valid_in),
        .ready_in  (m1_ready_in),
        .data_in   (m1_data_in),
        .valid_out (merge_to_slice_valid[1]),
        .ready_out (slice_to_merge_ready[1]),
        .data_out  (merge_to_slice_data[1])
    );

    assign vc_ready[0][0] = m1_ready_in[0];
    assign vc_ready[2][1] = m1_ready_in[1];
    assign vc_ready[3][1] = m1_ready_in[2];
    assign vc_ready[4][1] = m1_ready_in[3];

    // ── MERGE 2 (OUTPUT E, internal idx 2) ──
    // Sources: N→E  vc[0][1]  |  S→E  vc[1][1]  |  W→E  vc[3][2]  |  L→E  vc[4][2]
    logic [7:0] m2_data_in [0:3];
    logic [3:0] m2_valid_in;
    logic [3:0] m2_ready_in;

    assign m2_data_in[0] = vc_data[0][1];
    assign m2_data_in[1] = vc_data[1][1];
    assign m2_data_in[2] = vc_data[3][2];
    assign m2_data_in[3] = vc_data[4][2];

    assign m2_valid_in[0] = vc_valid[0][1];
    assign m2_valid_in[1] = vc_valid[1][1];
    assign m2_valid_in[2] = vc_valid[3][2];
    assign m2_valid_in[3] = vc_valid[4][2];

    merge_4to1_comb u_merge_2 (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (m2_valid_in),
        .ready_in  (m2_ready_in),
        .data_in   (m2_data_in),
        .valid_out (merge_to_slice_valid[2]),
        .ready_out (slice_to_merge_ready[2]),
        .data_out  (merge_to_slice_data[2])
    );

    assign vc_ready[0][1] = m2_ready_in[0];
    assign vc_ready[1][1] = m2_ready_in[1];
    assign vc_ready[3][2] = m2_ready_in[2];
    assign vc_ready[4][2] = m2_ready_in[3];

    // ── MERGE 3 (OUTPUT W, internal idx 3) ──
    // Sources: N→W  vc[0][2]  |  S→W  vc[1][2]  |  E→W  vc[2][2]  |  L→W  vc[4][3]
    logic [7:0] m3_data_in [0:3];
    logic [3:0] m3_valid_in;
    logic [3:0] m3_ready_in;

    assign m3_data_in[0] = vc_data[0][2];
    assign m3_data_in[1] = vc_data[1][2];
    assign m3_data_in[2] = vc_data[2][2];
    assign m3_data_in[3] = vc_data[4][3];

    assign m3_valid_in[0] = vc_valid[0][2];
    assign m3_valid_in[1] = vc_valid[1][2];
    assign m3_valid_in[2] = vc_valid[2][2];
    assign m3_valid_in[3] = vc_valid[4][3];

    merge_4to1_comb u_merge_3 (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (m3_valid_in),
        .ready_in  (m3_ready_in),
        .data_in   (m3_data_in),
        .valid_out (merge_to_slice_valid[3]),
        .ready_out (slice_to_merge_ready[3]),
        .data_out  (merge_to_slice_data[3])
    );

    assign vc_ready[0][2] = m3_ready_in[0];
    assign vc_ready[1][2] = m3_ready_in[1];
    assign vc_ready[2][2] = m3_ready_in[2];
    assign vc_ready[4][3] = m3_ready_in[3];

    // ── MERGE 4 (OUTPUT L, internal idx 4) ──
    // Sources: N→L  vc[0][3]  |  S→L  vc[1][3]  |  E→L  vc[2][3]  |  W→L  vc[3][3]
    logic [7:0] m4_data_in [0:3];
    logic [3:0] m4_valid_in;
    logic [3:0] m4_ready_in;

    assign m4_data_in[0] = vc_data[0][3];
    assign m4_data_in[1] = vc_data[1][3];
    assign m4_data_in[2] = vc_data[2][3];
    assign m4_data_in[3] = vc_data[3][3];

    assign m4_valid_in[0] = vc_valid[0][3];
    assign m4_valid_in[1] = vc_valid[1][3];
    assign m4_valid_in[2] = vc_valid[2][3];
    assign m4_valid_in[3] = vc_valid[3][3];

    merge_4to1_comb u_merge_4 (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (m4_valid_in),
        .ready_in  (m4_ready_in),
        .data_in   (m4_data_in),
        .valid_out (merge_to_slice_valid[4]),
        .ready_out (slice_to_merge_ready[4]),
        .data_out  (merge_to_slice_data[4])
    );

    assign vc_ready[0][3] = m4_ready_in[0];
    assign vc_ready[1][3] = m4_ready_in[1];
    assign vc_ready[2][3] = m4_ready_in[2];
    assign vc_ready[3][3] = m4_ready_in[3];

    // =========================================================================
    // OUTPUT SLICES (5) — depth-1 valid_ready_slice (UNCHANGED)
    // =========================================================================
    genvar go;
    generate
        for (go = 0; go < 5; go = go + 1) begin : g_output_slice
            valid_ready_slice u_output_slice (
                .clk       (clk),
                .rst_n     (rst_n),
                .data_in   (merge_to_slice_data[go]),
                .valid_in  (merge_to_slice_valid[go]),
                .ready_out (slice_to_merge_ready[go]),
                .data_out  (out_data_int[go]),
                .valid_out (out_valid_int[go]),
                .ready_in  (out_ready_int[go])
            );
        end
    endgenerate

endmodule


// =============================================================================
// 6. torus_router_5x5 — wrapper: now instantiates router_fifo_v2
//    Interface is byte-for-byte identical to the original; torus_4x4.sv
//    requires no changes.
// =============================================================================
module torus_router_5x5 #(
    parameter int CURR_X     = 0,
    parameter int CURR_Y     = 0,
    parameter int FIFO_DEPTH = 32
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

    router_fifo_v2 #(
        .FIFO_DEPTH (FIFO_DEPTH)
    ) u_router (
        .clk        (clk),
        .rst_n      (rst_n),
        .my_x       (CURR_X[1:0]),
        .my_y       (CURR_Y[1:0]),

        .in_valid   (in_vld),
        .in_ready   (in_rdy),
        .in_data_0  (in_data[0]),   // LOCAL
        .in_data_1  (in_data[1]),   // EAST
        .in_data_2  (in_data[2]),   // WEST
        .in_data_3  (in_data[3]),   // NORTH
        .in_data_4  (in_data[4]),   // SOUTH

        .out_valid  (out_vld),
        .out_ready  (out_rdy),
        .out_data_0 (out_data[0]),
        .out_data_1 (out_data[1]),
        .out_data_2 (out_data[2]),
        .out_data_3 (out_data[3]),
        .out_data_4 (out_data[4])
    );

endmodule