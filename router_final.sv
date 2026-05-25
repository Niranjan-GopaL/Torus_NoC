`timescale 1ns/1ps

// =============================================================================
// 1. xy_route_logic — XY Routing Decode
//   Decodes the destination from flit[7:4] and emits a 3-bit port select.
//   Port encoding: N=0, S=1, E=2, W=3, L=4
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

    always_comb begin
        if (dst_x > my_x)
            out_port = PORT_E;
        else if (dst_x < my_x)
            out_port = PORT_W;
        else if (dst_y > my_y)
            out_port = PORT_N;
        else if (dst_y < my_y)
            out_port = PORT_S;
        else
            out_port = PORT_L;
    end

endmodule


// =============================================================================
// 2. valid_ready_slice — Unified skid buffer (one module for both input & output)
//
// Replaces the previous input_valid_ready_slice / output_valid_ready_slice pair.
// Generic naming:
//   • data_in / valid_in / ready_out  — upstream side
//   • data_out / valid_out / ready_in — downstream side
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

    logic        data_valid;
    logic [7:0]  data_reg;

    // Ready when: no valid data stored OR downstream can accept
    assign ready_out = (!rst_n) ? 1'b0 : !data_valid || ready_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_valid <= 1'b0;
            data_reg   <= 8'h00;
        end else if (valid_in && ready_out) begin
            data_valid <= 1'b1;
            data_reg   <= data_in;
        end else if (data_valid && ready_in) begin
            data_valid <= 1'b0;
        end
    end

    // Valid when: holding data OR new data arriving this cycle
    assign valid_out = data_valid || (valid_in && ready_out);

    // Data out: stored data if valid, otherwise incoming data
    assign data_out  = data_valid ? data_reg : data_in;

endmodule


// =============================================================================
// 3. split_1to4_simple — 1→4 Demux with XY routing
//   No U-turn: each input excludes its own direction in the output index map.
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

            // N excludes N
            0: begin
                case (global_port)
                    1: dest_index = 0;
                    2: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

            // S excludes S
            1: begin
                case (global_port)
                    0: dest_index = 0;
                    2: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

            // E excludes E
            2: begin
                case (global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

            // W excludes W
            3: begin
                case (global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    2: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

            // L excludes L
            4: begin
                case (global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    2: dest_index = 2;
                    3: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

        endcase

        if (valid_in)
            valid_out[dest_index] = 1'b1;

        ready_in = ready_out[dest_index];
    end

    assign data_out = data_in;

endmodule


// =============================================================================
// 4. merge_4to1_comb — 4→1 Merge with Round-Robin Arbitration
//
// Merges 4 input channels into 1 output stream using round-robin arbitration.
// Losers hold their request high, which propagates back-pressure upstream.
//
// Arbitration Algorithm:
//   • Maintain a 'mask' register that tracks which ports are still eligible
//   • When grant is served, clear that port's mask bit
//   • When all masks are exhausted (or only unserved ports become active),
//     reset the mask to all-ones and start a new round
//   • Grant = lowest-indexed active port within the mask (priority encoder)
//   • Fallback: if no masked request is active, grant the overall lowest active
//
// Round-Robin Pointer Sequence:
//   Round 1: grant 0 -> 1 -> 2 -> 3 -> reset
//   Round 2: grant 1 -> 2 -> 3 -> 0 -> reset
//   Every port gets exactly one grant per complete round (fairness guaranteed)
// =============================================================================
module merge_4to1_comb #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_PORTS  = 4
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // ── Producer interfaces (from 4 split outputs) ──
    input  logic [NUM_PORTS-1:0]        valid_in,
    output logic [NUM_PORTS-1:0]        ready_in,
    input  logic [DATA_WIDTH-1:0]       data_in [0:NUM_PORTS-1],

    // ── Consumer interface (to output slice) ──
    output logic                        valid_out,
    input  logic                        ready_out,
    output logic [DATA_WIDTH-1:0]       data_out
);

    // ── Arbitration state ──
    logic [NUM_PORTS-1:0]               mask;
    logic [NUM_PORTS-1:0]               masked_req;
    logic [NUM_PORTS-1:0]               unmasked_grant;
    logic [NUM_PORTS-1:0]               grant;
    logic [$clog2(NUM_PORTS)-1:0]       selected_port;

    // ── Step 1: masked / unmasked requests ──
    assign masked_req     = valid_in & mask;
    assign unmasked_grant = valid_in & (~valid_in + 1);

    // ── Step 2: select grant (masked first, fallback to unmasked) ──
    assign grant = (|masked_req) ? (masked_req & (~masked_req + 1)) : unmasked_grant;

    // ── Step 3: one-hot to binary index ──
    assign selected_port = (grant == '0) ? '0 : $clog2(grant & -grant);

    // ── Step 4: combinational outputs ──
    assign ready_in  = grant & {NUM_PORTS{ready_out}};
    assign valid_out = |grant && ready_out;
    assign data_out  = (valid_out && ready_out) ? data_in[selected_port] : '0;

    // ── Step 5: round-robin mask update ──
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
// 5. router_simple — Top-level router
//   5 input slices + 5 splits + 5 round-robin merges + 5 output slices.
//   External port order (testbench): [LOCAL, EAST, WEST, NORTH, SOUTH]
//   Internal port order:             [N, S, E, W, L]
// =============================================================================
module router_simple (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [1:0]  my_x,
    input  logic [1:0]  my_y,

    // External inputs — order: [LOCAL, EAST, WEST, NORTH, SOUTH]
    input  logic [4:0]  in_valid,
    input  logic [7:0]  in_data_0,  // LOCAL
    input  logic [7:0]  in_data_1,  // EAST
    input  logic [7:0]  in_data_2,  // WEST
    input  logic [7:0]  in_data_3,  // NORTH
    input  logic [7:0]  in_data_4,  // SOUTH
    output logic [4:0]  in_ready,

    // External outputs — order: [LOCAL, EAST, WEST, NORTH, SOUTH]
    output logic [4:0]  out_valid,
    output logic [7:0]  out_data_0,  // LOCAL
    output logic [7:0]  out_data_1,  // EAST
    output logic [7:0]  out_data_2,  // WEST
    output logic [7:0]  out_data_3,  // NORTH
    output logic [7:0]  out_data_4,  // SOUTH
    input  logic [4:0]  out_ready
);

    // =========================================================================
    // Port remap: testbench [L,E,W,N,S] <-> internal [N,S,E,W,L]
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
        out_valid[0] = out_valid_int[4];   // LOCAL <- PORT_L
        out_valid[1] = out_valid_int[2];   // EAST  <- PORT_E
        out_valid[2] = out_valid_int[3];   // WEST  <- PORT_W
        out_valid[3] = out_valid_int[0];   // NORTH <- PORT_N
        out_valid[4] = out_valid_int[1];   // SOUTH <- PORT_S

        out_data_0 = out_data_int[4];
        out_data_1 = out_data_int[2];
        out_data_2 = out_data_int[3];
        out_data_3 = out_data_int[0];
        out_data_4 = out_data_int[1];

        out_ready_int[4] = out_ready[0];
        out_ready_int[2] = out_ready[1];
        out_ready_int[3] = out_ready[2];
        out_ready_int[0] = out_ready[3];
        out_ready_int[1] = out_ready[4];

        in_ready[3] = in_ready_int[0];
        in_ready[4] = in_ready_int[1];
        in_ready[1] = in_ready_int[2];
        in_ready[2] = in_ready_int[3];
        in_ready[0] = in_ready_int[4];
    end

    // =========================================================================
    // Internal wires
    // =========================================================================

    // Input slice → split
    logic [7:0] slice_to_split_data  [4:0];
    logic [4:0] slice_to_split_valid;
    logic [4:0] split_to_slice_ready;

    // Split → merge (4 outputs per split, one per non-self direction)
    logic [3:0] split_valid [4:0];
    logic [3:0] split_ready [4:0];
    logic [7:0] split_data  [4:0];

    // Merge → output slice
    logic [7:0] merge_to_slice_data  [4:0];
    logic [4:0] merge_to_slice_valid;
    logic [4:0] slice_to_merge_ready;

    // =========================================================================
    // INPUT SLICES (5)
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
    // SPLITS (5) — one per input direction
    // =========================================================================
    split_1to4_simple #(.INPUT_PORT(0)) u_split_0 (
        .valid_in  (slice_to_split_valid[0]),
        .data_in   (slice_to_split_data[0]),
        .ready_in  (split_to_slice_ready[0]),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid[0]),
        .data_out  (split_data[0]),
        .ready_out (split_ready[0])
    );

    split_1to4_simple #(.INPUT_PORT(1)) u_split_1 (
        .valid_in  (slice_to_split_valid[1]),
        .data_in   (slice_to_split_data[1]),
        .ready_in  (split_to_slice_ready[1]),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid[1]),
        .data_out  (split_data[1]),
        .ready_out (split_ready[1])
    );

    split_1to4_simple #(.INPUT_PORT(2)) u_split_2 (
        .valid_in  (slice_to_split_valid[2]),
        .data_in   (slice_to_split_data[2]),
        .ready_in  (split_to_slice_ready[2]),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid[2]),
        .data_out  (split_data[2]),
        .ready_out (split_ready[2])
    );

    split_1to4_simple #(.INPUT_PORT(3)) u_split_3 (
        .valid_in  (slice_to_split_valid[3]),
        .data_in   (slice_to_split_data[3]),
        .ready_in  (split_to_slice_ready[3]),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid[3]),
        .data_out  (split_data[3]),
        .ready_out (split_ready[3])
    );

    split_1to4_simple #(.INPUT_PORT(4)) u_split_4 (
        .valid_in  (slice_to_split_valid[4]),
        .data_in   (slice_to_split_data[4]),
        .ready_in  (split_to_slice_ready[4]),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid[4]),
        .data_out  (split_data[4]),
        .ready_out (split_ready[4])
    );

    // =========================================================================
    // MERGES (5) — round-robin, one per output direction
    // Each merge gathers the 4 splits that can target this output direction.
    // =========================================================================

    // ── OUTPUT N (idx 0): from splits S(1), E(2), W(3), L(4) ──
    logic [7:0] m0_data_in [0:3];
    logic [3:0] m0_valid_in;
    logic [3:0] m0_ready_in;

    assign m0_data_in[0] = split_data[1];
    assign m0_data_in[1] = split_data[2];
    assign m0_data_in[2] = split_data[3];
    assign m0_data_in[3] = split_data[4];

    assign m0_valid_in = { split_valid[4][0],
                           split_valid[3][0],
                           split_valid[2][0],
                           split_valid[1][0] };

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

    assign split_ready[1][0] = m0_ready_in[0];
    assign split_ready[2][0] = m0_ready_in[1];
    assign split_ready[3][0] = m0_ready_in[2];
    assign split_ready[4][0] = m0_ready_in[3];

    // ── OUTPUT S (idx 1): from splits N(0), E(2), W(3), L(4) ──
    logic [7:0] m1_data_in [0:3];
    logic [3:0] m1_valid_in;
    logic [3:0] m1_ready_in;

    assign m1_data_in[0] = split_data[0];
    assign m1_data_in[1] = split_data[2];
    assign m1_data_in[2] = split_data[3];
    assign m1_data_in[3] = split_data[4];

    assign m1_valid_in = { split_valid[4][1],
                           split_valid[3][1],
                           split_valid[2][1],
                           split_valid[0][0] };

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

    assign split_ready[0][0] = m1_ready_in[0];
    assign split_ready[2][1] = m1_ready_in[1];
    assign split_ready[3][1] = m1_ready_in[2];
    assign split_ready[4][1] = m1_ready_in[3];

    // ── OUTPUT E (idx 2): from splits N(0), S(1), W(3), L(4) ──
    logic [7:0] m2_data_in [0:3];
    logic [3:0] m2_valid_in;
    logic [3:0] m2_ready_in;

    assign m2_data_in[0] = split_data[0];
    assign m2_data_in[1] = split_data[1];
    assign m2_data_in[2] = split_data[3];
    assign m2_data_in[3] = split_data[4];

    assign m2_valid_in = { split_valid[4][2],
                           split_valid[3][2],
                           split_valid[1][1],
                           split_valid[0][1] };

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

    assign split_ready[0][1] = m2_ready_in[0];
    assign split_ready[1][1] = m2_ready_in[1];
    assign split_ready[3][2] = m2_ready_in[2];
    assign split_ready[4][2] = m2_ready_in[3];

    // ── OUTPUT W (idx 3): from splits N(0), S(1), E(2), L(4) ──
    logic [7:0] m3_data_in [0:3];
    logic [3:0] m3_valid_in;
    logic [3:0] m3_ready_in;

    assign m3_data_in[0] = split_data[0];
    assign m3_data_in[1] = split_data[1];
    assign m3_data_in[2] = split_data[2];
    assign m3_data_in[3] = split_data[4];

    assign m3_valid_in = { split_valid[4][3],
                           split_valid[2][2],
                           split_valid[1][2],
                           split_valid[0][2] };

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

    assign split_ready[0][2] = m3_ready_in[0];
    assign split_ready[1][2] = m3_ready_in[1];
    assign split_ready[2][2] = m3_ready_in[2];
    assign split_ready[4][3] = m3_ready_in[3];

    // ── OUTPUT L (idx 4): from splits N(0), S(1), E(2), W(3) ──
    logic [7:0] m4_data_in [0:3];
    logic [3:0] m4_valid_in;
    logic [3:0] m4_ready_in;

    assign m4_data_in[0] = split_data[0];
    assign m4_data_in[1] = split_data[1];
    assign m4_data_in[2] = split_data[2];
    assign m4_data_in[3] = split_data[3];

    assign m4_valid_in = { split_valid[3][3],
                           split_valid[2][3],
                           split_valid[1][3],
                           split_valid[0][3] };

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

    assign split_ready[0][3] = m4_ready_in[0];
    assign split_ready[1][3] = m4_ready_in[1];
    assign split_ready[2][3] = m4_ready_in[2];
    assign split_ready[3][3] = m4_ready_in[3];

    // =========================================================================
    // OUTPUT SLICES (5) — same module as input slices
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
// 6. torus_router_5x5 — Wrapper matching the testbench interface
// =============================================================================
module torus_router_5x5 #(
    parameter int CURR_X = 0,
    parameter int CURR_Y = 0
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

    router_simple u_router (
        .clk         (clk),
        .rst_n       (rst_n),
        .my_x        (CURR_X[1:0]),
        .my_y        (CURR_Y[1:0]),

        .in_valid    (in_vld),
        .in_ready    (in_rdy),
        .in_data_0   (in_data[0]),  // LOCAL
        .in_data_1   (in_data[1]),  // EAST
        .in_data_2   (in_data[2]),  // WEST
        .in_data_3   (in_data[3]),  // NORTH
        .in_data_4   (in_data[4]),  // SOUTH

        .out_valid   (out_vld),
        .out_ready   (out_rdy),
        .out_data_0  (out_data[0]),
        .out_data_1  (out_data[1]),
        .out_data_2  (out_data[2]),
        .out_data_3  (out_data[3]),
        .out_data_4  (out_data[4])
    );

endmodule
