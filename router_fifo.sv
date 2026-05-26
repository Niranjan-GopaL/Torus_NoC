`timescale 1ns/1ps

// =============================================================================
// 1. xy_route_logic - XY Routing Decode 
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

//    always_comb begin
//        if (dst_x > my_x)
//            out_port = PORT_E;
//        else if (dst_x < my_x)
//            out_port = PORT_W;
//        else if (dst_y > my_y)
//            out_port = PORT_N;
//        else if (dst_y < my_y)
//            out_port = PORT_S;
//        else
//            out_port = PORT_L;
//    end


    // Odd Even routing algorithm

    // always_comb begin
    //     // Check if we've reached the destination
    //     if ((dst_x == my_x) && (dst_y == my_y)) begin
    //         out_port = PORT_L;
    //     end
    //     // Odd-Even routing logic
    //     else begin
    //         // Determine if current column is even or odd
    //         // Assuming my_x[0] = 0 means even, my_x[0] = 1 means odd
    //         if (my_x[0] == 0) begin  // Even column
    //             // In even columns, allow turns from North/South to East/West
    //             if (dst_x != my_x) begin
    //                 // Prefer horizontal movement first
    //                 if (dst_x > my_x)
    //                     out_port = PORT_E;
    //                 else
    //                     out_port = PORT_W;
    //             end
    //             else begin
    //                 // Same column, move vertically
    //                 if (dst_y > my_y)
    //                     out_port = PORT_N;
    //                 else
    //                     out_port = PORT_S;
    //             end
    //         end
    //         else begin  // Odd column
    //             // In odd columns, restrict East-West turns
    //             if ((dst_y != my_y) && (dst_x == my_x)) begin
    //                 // Same column, move vertically first
    //                 if (dst_y > my_y)
    //                     out_port = PORT_N;
    //                 else
    //                     out_port = PORT_S;
    //             end
    //             else begin
    //                 // Then move horizontally
    //                 if (dst_x > my_x)
    //                     out_port = PORT_E;
    //                 else if (dst_x < my_x)
    //                     out_port = PORT_W;
    //                 else
    //                     out_port = PORT_L;  // Should not reach here
    //             end
    //         end
    //     end
    // end




    logic [1:0] fdx, fdy;   // forward (East/North) ring distance, mod 4

    always_comb begin
        fdx = (dst_x - my_x) & 2'b11;
        fdy = (dst_y - my_y) & 2'b11;

        // ---- X first (dimension order) ----
        if (fdx != 2'd0) begin
            if (fdx == 2'd1)
                out_port = PORT_E;                          // +1 (wrap if my_x==3)
            else if (fdx == 2'd3)
                out_port = PORT_W;                          // -1 (wrap if my_x==0)
            else // fdx == 2 : opposite, tie -> split by coord to break the cycle
                out_port = (my_x < 2'd2) ? PORT_E : PORT_W;
        end
        // ---- then Y ----
        else if (fdy != 2'd0) begin
            if (fdy == 2'd1)
                out_port = PORT_N;                          // +1 (wrap if my_y==3)
            else if (fdy == 2'd3)
                out_port = PORT_S;                          // -1 (wrap if my_y==0)
            else // fdy == 2 : opposite, tie -> split by coord
                out_port = (my_y < 2'd2) ? PORT_N : PORT_S;
        end
        else
            out_port = PORT_L;
    end

endmodule


// =============================================================================
// 2. valid_ready_slice - Unified skid buffer (UNCHANGED, kept for A/B + outputs)
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

    assign ready_out = rst_n && (!data_valid || ready_in) ;

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
// 2b. fifo_sync - Synchronous FIFO, drop-in replacement for valid_ready_slice
//
//   PIN-COMPATIBLE with valid_ready_slice: identical port names + handshake
//   contract, so it can be swapped in the input-slice instantiation with no
//   other change to router_simple / router_with_fifo.
//
//   Handshake contract (matches the skid buffer it replaces):
//     • ready_out = !full   - depends ONLY on internal occupancy, never on
//                             ready_in. No combinational ready->ready path.
//     • valid_out = !empty  - derived from registered pointers, no
//                             combinational fall-through of data_in/valid_in.
//     • data_out  = mem[rd_ptr] - registered FIFO head.
//
//   Full/empty: extra-MSB pointer trick. Pointers are PTR_WIDTH+1 bits.
//     empty = (wr_ptr == rd_ptr)
//     full  = (addr bits equal) && (MSBs differ)
//
//   Depth-correctness for non-power-of-2 DEPTH:
//     The address part wraps explicitly at DEPTH-1 and the wrap (MSB) bit
//     toggles on that wrap. This keeps the extra-MSB trick valid for any
//     DEPTH >= 2, not just powers of two.
// =============================================================================
module fifo_sync #(
    parameter int DEPTH      = 4,
    parameter int DATA_WIDTH = 8
)(
    input  logic                   clk,
    input  logic                   rst_n,

    // ── upstream side (matches valid_ready_slice) ──
    input  logic [DATA_WIDTH-1:0]  data_in,
    input  logic                   valid_in,
    output logic                   ready_out,

    // ── downstream side (matches valid_ready_slice) ──
    output logic [DATA_WIDTH-1:0]  data_out,
    output logic                   valid_out,
    input  logic                   ready_in
);

    // Address width: enough bits to index DEPTH locations.
    localparam int PTR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers carry one extra MSB (the "wrap" bit) for full/empty disambiguation.
    logic [PTR_WIDTH:0] wr_ptr;
    logic [PTR_WIDTH:0] rd_ptr;

    logic empty;
    logic full;

    // ── Full/Empty Detection (extra-MSB trick) ──
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
                   (wr_ptr[PTR_WIDTH]      != rd_ptr[PTR_WIDTH]);

    // ── Handshake outputs ──
    // ready_out depends only on occupancy (full), NOT on ready_in.
    assign ready_out = rst_n && !full;
    assign valid_out = !empty;
    assign data_out  = mem[rd_ptr[PTR_WIDTH-1:0]];

    // ── Push / Pop conditions ──
    logic do_push;
    logic do_pop;
    assign do_push = valid_in  && ready_out;   // accepted on upstream side
    assign do_pop  = valid_out && ready_in;    // accepted on downstream side

    // ── Pointer-advance helper (explicit wrap at DEPTH-1, toggle MSB) ──
    // Increments a {wrap, addr} pointer. addr wraps DEPTH-1 -> 0 and flips MSB.
    function automatic logic [PTR_WIDTH:0] ptr_next(input logic [PTR_WIDTH:0] p);
        logic [PTR_WIDTH-1:0] addr;
        logic                 wrap;
        begin
            addr = p[PTR_WIDTH-1:0];
            wrap = p[PTR_WIDTH];
            if (addr == (DEPTH-1)) begin
                addr = '0;
                wrap = ~wrap;
            end else begin
                addr = addr + 1'b1;
            end
            ptr_next = {wrap, addr};
        end
    endfunction

    // ── Sequential update ──
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (do_push) begin
                mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in;
                wr_ptr                     <= ptr_next(wr_ptr);
            end
            if (do_pop) begin
                rd_ptr <= ptr_next(rd_ptr);
            end
        end
    end

endmodule


// =============================================================================
// 3. split_1to4_simple - 1->4 Demux with XY routing  
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
            0: begin
                case (global_port)
                    1: dest_index = 0;
                    2: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end
            1: begin
                case (global_port)
                    0: dest_index = 0;
                    2: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end
            2: begin
                case (global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end
            3: begin
                case (global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    2: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end
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
// 4. merge_4to1_comb - 4->1 Merge with Round-Robin Arbitration  
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

    logic [NUM_PORTS-1:0]               mask;
    logic [NUM_PORTS-1:0]               masked_req;
    logic [NUM_PORTS-1:0]               unmasked_grant;
    logic [NUM_PORTS-1:0]               grant;
    logic [$clog2(NUM_PORTS)-1:0]       selected_port;

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
// 5. router_with_fifo - Top-level router (was router_simple)
//
//   ONLY CHANGE vs router_simple: the 5 INPUT slices are now fifo_sync of
//   depth FIFO_DEPTH (default 4). Output slices, splits, merges, the port
//   remap, and all wiring are byte-for-byte identical to the proven design.
//
//   External port order (testbench): [LOCAL, EAST, WEST, NORTH, SOUTH]
//   Internal port order:             [N, S, E, W, L]
// =============================================================================
module router_with_fifo #(
    parameter int FIFO_DEPTH = 4
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic [1:0]  my_x,
    input  logic [1:0]  my_y,

    // External inputs - order: [LOCAL, EAST, WEST, NORTH, SOUTH]
    input  logic [4:0]  in_valid,
    input  logic [7:0]  in_data_0,  // LOCAL
    input  logic [7:0]  in_data_1,  // EAST
    input  logic [7:0]  in_data_2,  // WEST
    input  logic [7:0]  in_data_3,  // NORTH
    input  logic [7:0]  in_data_4,  // SOUTH
    output logic [4:0]  in_ready,

    // External outputs - order: [LOCAL, EAST, WEST, NORTH, SOUTH]
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
    logic [7:0] slice_to_split_data  [4:0];
    logic [4:0] slice_to_split_valid;
    logic [4:0] split_to_slice_ready;

    logic [3:0] split_valid [4:0];
    logic [3:0] split_ready [4:0];
    logic [7:0] split_data  [4:0];

    logic [7:0] merge_to_slice_data  [4:0];
    logic [4:0] merge_to_slice_valid;
    logic [4:0] slice_to_merge_ready;

    // =========================================================================
    // INPUT FIFOs (5)  - ONLY structural change: fifo_sync instead of slice.
    // Same port connections as the original input valid_ready_slice block.
    // =========================================================================
    genvar gi;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : g_input_fifo
            fifo_sync #(
                .DEPTH      (FIFO_DEPTH),
                .DATA_WIDTH (8)
            ) u_input_fifo (
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
    // SPLITS (5)  
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
    // MERGES (5)  
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
    // OUTPUT SLICES (5) - kept as depth-1 valid_ready_slice 
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
// 6. torus_router_5x5 - Wrapper matching the testbench interface
//   UNCHANGED except it now instantiates router_with_fifo and forwards
//   FIFO_DEPTH. Interface is byte-for-byte identical to the original.
// =============================================================================
module torus_router_5x5 #(
    parameter int CURR_X     = 0,
    parameter int CURR_Y     = 0,
    parameter int FIFO_DEPTH =  64
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

    router_with_fifo #(
        .FIFO_DEPTH (FIFO_DEPTH)
    ) u_router (
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