`timescale 1ns/1ps

// =============================================================================
//  5-port torus router, FIFO-buffered on BOTH input and output stages (v2)
//
//  Same as router_fifo.sv, but now the output stage uses a real FIFO too. The
//  output FIFO acts as a small elasticity buffer between the merge arbiter and
//  whatever sits downstream on the link: the merge can keep granting flits even
//  if the downstream router is briefly slow to accept them, which smooths out
//  the per-port backpressure that the round-robin sees.
//
//  Input and output depths are separately parameterizable.
//
//  Pipeline: input FIFO -> split -> round-robin merge -> output FIFO.
//  Flit format: 8 bits, top nibble = destination ([7:6]=x, [5:4]=y).
//  Port encoding (internal): N=0, S=1, E=2, W=3, L=4
// =============================================================================


// =============================================================================
//  xy_route_logic - pick the output port (custom torus routing)
//
//  Ring distance wraps mod 4, so we take the shorter way round, X before Y.
//  Distance of 2 is a tie (both ways equal); we break it by coordinate so the
//  flow doesn't form a cycle.
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

    logic [1:0] fdx, fdy;   // forward (E/N) ring distance, mod 4

    always_comb begin
        fdx = (dst_x - my_x) & 2'b11;
        fdy = (dst_y - my_y) & 2'b11;

        if (fdx != 2'd0) begin                      // sort out X first
            if      (fdx == 2'd1) out_port = PORT_E; // one step forward
            else if (fdx == 2'd3) out_port = PORT_W; // one step back (shorter)
            else                  out_port = (my_x < 2'd2) ? PORT_E : PORT_W; // tie
        end
        else if (fdy != 2'd0) begin                 // then Y
            if      (fdy == 2'd1) out_port = PORT_N;
            else if (fdy == 2'd3) out_port = PORT_S;
            else                  out_port = (my_y < 2'd2) ? PORT_N : PORT_S; // tie
        end
        else
            out_port = PORT_L;                       // arrived
    end

endmodule


// =============================================================================
//  fifo_sync - synchronous FIFO, used at both input and output stages
//
//  Pin-compatible handshake: ready_out depends only on occupancy (!full),
//  valid_out on !empty, data_out is the registered head.
//
//  Full/empty use the classic extra-MSB pointer trick: pointers are one bit
//  wider than the address. Same address but different MSB => full; fully equal
//  => empty. The address part wraps explicitly at DEPTH-1 and flips the MSB on
//  wrap, so this works for any DEPTH >= 2, not just powers of two.
// =============================================================================
module fifo_sync #(
    parameter int DEPTH      = 4,
    parameter int DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  valid_in,
    output logic                  ready_out,

    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  valid_out,
    input  logic                  ready_in
);

    localparam int PTR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH:0]    wr_ptr, rd_ptr;   // extra MSB = wrap bit
    logic                  empty, full;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) &&
                   (wr_ptr[PTR_WIDTH]      != rd_ptr[PTR_WIDTH]);

    assign ready_out = rst_n && !full;
    assign valid_out = !empty;
    assign data_out  = mem[rd_ptr[PTR_WIDTH-1:0]];

    logic do_push;
    logic do_pop;
    assign do_push = valid_in  && ready_out;
    assign do_pop  = valid_out && ready_in;

    // Advance a {wrap, addr} pointer: addr wraps DEPTH-1 -> 0 and flips the MSB.
    function automatic logic [PTR_WIDTH:0] ptr_next(input logic [PTR_WIDTH:0] p);
        logic [PTR_WIDTH-1:0] addr; logic wrap;
        begin
            addr = p[PTR_WIDTH-1:0];
            wrap = p[PTR_WIDTH];
            if (addr == (DEPTH-1)) begin addr = '0; wrap = ~wrap; end
            else                        addr = addr + 1'b1;
            ptr_next = {wrap, addr};
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (do_push) begin mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in; wr_ptr <= ptr_next(wr_ptr); end
            if (do_pop)  rd_ptr <= ptr_next(rd_ptr);
        end
    end

endmodule


// =============================================================================
//  split_1to4_simple - route a flit, send it out one of 4 non-self ports
//
//  Asks the route logic for a direction, then maps that to one of four outputs
//  (a flit never leaves the way it came, so each input excludes its own port).
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

    logic [2:0] global_port;   // chosen direction 0..4
    logic [1:0] dest_index;    // mapped to our output 0..3

    xy_route_logic u_xy (.data_in(data_in), .my_x(my_x), .my_y(my_y), .out_port(global_port));

    always_comb begin
        valid_out  = 4'b0000;
        ready_in   = 1'b0;
        dest_index = 2'd0;

        // Each input drops its own direction; the rest pack into indices 0..3.
        case (INPUT_PORT)
            0: case (global_port) 1:dest_index=0; 2:dest_index=1; 3:dest_index=2; 4:dest_index=3; default:dest_index=0; endcase // N
            1: case (global_port) 0:dest_index=0; 2:dest_index=1; 3:dest_index=2; 4:dest_index=3; default:dest_index=0; endcase // S
            2: case (global_port) 0:dest_index=0; 1:dest_index=1; 3:dest_index=2; 4:dest_index=3; default:dest_index=0; endcase // E
            3: case (global_port) 0:dest_index=0; 1:dest_index=1; 2:dest_index=2; 4:dest_index=3; default:dest_index=0; endcase // W
            4: case (global_port) 0:dest_index=0; 1:dest_index=1; 2:dest_index=2; 3:dest_index=3; default:dest_index=0; endcase // L
        endcase

        if (valid_in) valid_out[dest_index] = 1'b1;
        ready_in = ready_out[dest_index];   // backpressure from the chosen output
    end

    assign data_out = data_in;

endmodule


// =============================================================================
//  merge_4to1_comb - 4-to-1 merge with round-robin arbitration
//
//  Four inputs, one output. A 'mask' tracks who's been served this round so
//  everyone gets a turn before anyone repeats. Losers hold their request,
//  which pushes backpressure upstream on its own.
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

    logic [NUM_PORTS-1:0]         mask;            // still eligible this round
    logic [NUM_PORTS-1:0]         masked_req;
    logic [NUM_PORTS-1:0]         unmasked_grant;
    logic [NUM_PORTS-1:0]         grant;
    logic [$clog2(NUM_PORTS)-1:0] selected_port;

    // (x & -x) isolates the lowest set bit = simple priority pick.
    assign masked_req     = valid_in & mask;
    assign unmasked_grant = valid_in & (~valid_in + 1);
    assign grant = (|masked_req) ? (masked_req & (~masked_req + 1)) : unmasked_grant;

    // one-hot grant -> binary index, to pick the data word
    always_comb begin
        selected_port = '0;
        for (int i = NUM_PORTS-1; i >= 0; i--)
            if (grant[i]) selected_port = i[$clog2(NUM_PORTS)-1:0];
    end

    assign ready_in  = grant & {NUM_PORTS{ready_out}};
    assign valid_out = |grant;
    assign data_out  = data_in[selected_port];

    // Clear the served port from the mask; refill the mask when a round ends.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mask <= {NUM_PORTS{1'b1}};
        else if (valid_out && ready_out && |grant)
            mask <= (|masked_req) ? (mask & ~grant) : ({NUM_PORTS{1'b1}} & ~grant);
    end

endmodule


// =============================================================================
//  router_with_fifo_v2 - the full router, input FIFOs + output FIFOs
//
//  Five input FIFOs feed five splits, splits feed five round-robin merges, and
//  merges drain into five output FIFOs. Output FIFOs give the merge somewhere
//  to put a granted flit even if the downstream link is momentarily not ready,
//  so a single slow neighbor doesn't immediately starve everyone competing for
//  that direction.
//
//  Testbench port order is [LOCAL, EAST, WEST, NORTH, SOUTH]; internally we use
//  [N, S, E, W, L]. The remap below bridges the two.
// =============================================================================
module router_with_fifo_v2 #(
    parameter int IN_FIFO_DEPTH  = 4,
    parameter int OUT_FIFO_DEPTH = 4
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

    // External outputs - same order
    output logic [4:0]  out_valid,
    output logic [7:0]  out_data_0,
    output logic [7:0]  out_data_1,
    output logic [7:0]  out_data_2,
    output logic [7:0]  out_data_3,
    output logic [7:0]  out_data_4,
    input  logic [4:0]  out_ready
);

    // -------------------------------------------------------------------------
    //  Port remap: testbench [L,E,W,N,S]  <->  internal [N,S,E,W,L]
    // -------------------------------------------------------------------------
    logic [4:0] in_valid_int, in_ready_int;
    logic [7:0] in_data_int  [4:0];
    logic [4:0] out_valid_int, out_ready_int;
    logic [7:0] out_data_int [4:0];

    always_comb begin
        in_valid_int[0] = in_valid[3];  in_data_int[0] = in_data_3;  // N
        in_valid_int[1] = in_valid[4];  in_data_int[1] = in_data_4;  // S
        in_valid_int[2] = in_valid[1];  in_data_int[2] = in_data_1;  // E
        in_valid_int[3] = in_valid[2];  in_data_int[3] = in_data_2;  // W
        in_valid_int[4] = in_valid[0];  in_data_int[4] = in_data_0;  // L
    end

    always_comb begin
        out_valid[0] = out_valid_int[4];  out_data_0 = out_data_int[4];  // L
        out_valid[1] = out_valid_int[2];  out_data_1 = out_data_int[2];  // E
        out_valid[2] = out_valid_int[3];  out_data_2 = out_data_int[3];  // W
        out_valid[3] = out_valid_int[0];  out_data_3 = out_data_int[0];  // N
        out_valid[4] = out_valid_int[1];  out_data_4 = out_data_int[1];  // S

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

    // -------------------------------------------------------------------------
    //  Internal wiring
    // -------------------------------------------------------------------------
    logic [7:0] fifo_to_split_data  [4:0];   // input FIFO -> split
    logic [4:0] fifo_to_split_valid;
    logic [4:0] split_to_fifo_ready;

    logic [3:0] split_valid [4:0];           // split -> merge
    logic [3:0] split_ready [4:0];
    logic [7:0] split_data  [4:0];

    logic [7:0] merge_to_fifo_data  [4:0];   // merge -> output FIFO
    logic [4:0] merge_to_fifo_valid;
    logic [4:0] fifo_to_merge_ready;

    // -------------------------------------------------------------------------
    //  Input FIFOs (5)
    // -------------------------------------------------------------------------
    genvar gi;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : g_input_fifo
            fifo_sync #(.DEPTH(IN_FIFO_DEPTH), .DATA_WIDTH(8)) u_input_fifo (
                .clk(clk), .rst_n(rst_n),
                .data_in  (in_data_int[gi]),
                .valid_in (in_valid_int[gi]),
                .ready_out(in_ready_int[gi]),
                .data_out (fifo_to_split_data[gi]),
                .valid_out(fifo_to_split_valid[gi]),
                .ready_in (split_to_fifo_ready[gi])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    //  Splits (5) - one per input direction
    // -------------------------------------------------------------------------
    split_1to4_simple #(.INPUT_PORT(0)) u_split_0 (.valid_in(fifo_to_split_valid[0]), .data_in(fifo_to_split_data[0]), .ready_in(split_to_fifo_ready[0]), .my_x(my_x), .my_y(my_y), .valid_out(split_valid[0]), .data_out(split_data[0]), .ready_out(split_ready[0]));
    split_1to4_simple #(.INPUT_PORT(1)) u_split_1 (.valid_in(fifo_to_split_valid[1]), .data_in(fifo_to_split_data[1]), .ready_in(split_to_fifo_ready[1]), .my_x(my_x), .my_y(my_y), .valid_out(split_valid[1]), .data_out(split_data[1]), .ready_out(split_ready[1]));
    split_1to4_simple #(.INPUT_PORT(2)) u_split_2 (.valid_in(fifo_to_split_valid[2]), .data_in(fifo_to_split_data[2]), .ready_in(split_to_fifo_ready[2]), .my_x(my_x), .my_y(my_y), .valid_out(split_valid[2]), .data_out(split_data[2]), .ready_out(split_ready[2]));
    split_1to4_simple #(.INPUT_PORT(3)) u_split_3 (.valid_in(fifo_to_split_valid[3]), .data_in(fifo_to_split_data[3]), .ready_in(split_to_fifo_ready[3]), .my_x(my_x), .my_y(my_y), .valid_out(split_valid[3]), .data_out(split_data[3]), .ready_out(split_ready[3]));
    split_1to4_simple #(.INPUT_PORT(4)) u_split_4 (.valid_in(fifo_to_split_valid[4]), .data_in(fifo_to_split_data[4]), .ready_in(split_to_fifo_ready[4]), .my_x(my_x), .my_y(my_y), .valid_out(split_valid[4]), .data_out(split_data[4]), .ready_out(split_ready[4]));

    // -------------------------------------------------------------------------
    //  Merges (5) - one per output direction
    //  Each output gathers the four splits that can target it. The split_ready
    //  assigns close the backpressure loop.
    // -------------------------------------------------------------------------

    // OUTPUT N: from S, E, W, L
    logic [7:0] m0_data_in [0:3]; logic [3:0] m0_valid_in, m0_ready_in;
    assign m0_data_in[0]=split_data[1]; assign m0_data_in[1]=split_data[2]; assign m0_data_in[2]=split_data[3]; assign m0_data_in[3]=split_data[4];
    assign m0_valid_in = {split_valid[4][0], split_valid[3][0], split_valid[2][0], split_valid[1][0]};
    merge_4to1_comb u_merge_0 (.clk(clk), .rst_n(rst_n), .valid_in(m0_valid_in), .ready_in(m0_ready_in), .data_in(m0_data_in), .valid_out(merge_to_fifo_valid[0]), .ready_out(fifo_to_merge_ready[0]), .data_out(merge_to_fifo_data[0]));
    assign split_ready[1][0]=m0_ready_in[0]; assign split_ready[2][0]=m0_ready_in[1]; assign split_ready[3][0]=m0_ready_in[2]; assign split_ready[4][0]=m0_ready_in[3];

    // OUTPUT S: from N, E, W, L
    logic [7:0] m1_data_in [0:3]; logic [3:0] m1_valid_in, m1_ready_in;
    assign m1_data_in[0]=split_data[0]; assign m1_data_in[1]=split_data[2]; assign m1_data_in[2]=split_data[3]; assign m1_data_in[3]=split_data[4];
    assign m1_valid_in = {split_valid[4][1], split_valid[3][1], split_valid[2][1], split_valid[0][0]};
    merge_4to1_comb u_merge_1 (.clk(clk), .rst_n(rst_n), .valid_in(m1_valid_in), .ready_in(m1_ready_in), .data_in(m1_data_in), .valid_out(merge_to_fifo_valid[1]), .ready_out(fifo_to_merge_ready[1]), .data_out(merge_to_fifo_data[1]));
    assign split_ready[0][0]=m1_ready_in[0]; assign split_ready[2][1]=m1_ready_in[1]; assign split_ready[3][1]=m1_ready_in[2]; assign split_ready[4][1]=m1_ready_in[3];

    // OUTPUT E: from N, S, W, L
    logic [7:0] m2_data_in [0:3]; logic [3:0] m2_valid_in, m2_ready_in;
    assign m2_data_in[0]=split_data[0]; assign m2_data_in[1]=split_data[1]; assign m2_data_in[2]=split_data[3]; assign m2_data_in[3]=split_data[4];
    assign m2_valid_in = {split_valid[4][2], split_valid[3][2], split_valid[1][1], split_valid[0][1]};
    merge_4to1_comb u_merge_2 (.clk(clk), .rst_n(rst_n), .valid_in(m2_valid_in), .ready_in(m2_ready_in), .data_in(m2_data_in), .valid_out(merge_to_fifo_valid[2]), .ready_out(fifo_to_merge_ready[2]), .data_out(merge_to_fifo_data[2]));
    assign split_ready[0][1]=m2_ready_in[0]; assign split_ready[1][1]=m2_ready_in[1]; assign split_ready[3][2]=m2_ready_in[2]; assign split_ready[4][2]=m2_ready_in[3];

    // OUTPUT W: from N, S, E, L
    logic [7:0] m3_data_in [0:3]; logic [3:0] m3_valid_in, m3_ready_in;
    assign m3_data_in[0]=split_data[0]; assign m3_data_in[1]=split_data[1]; assign m3_data_in[2]=split_data[2]; assign m3_data_in[3]=split_data[4];
    assign m3_valid_in = {split_valid[4][3], split_valid[2][2], split_valid[1][2], split_valid[0][2]};
    merge_4to1_comb u_merge_3 (.clk(clk), .rst_n(rst_n), .valid_in(m3_valid_in), .ready_in(m3_ready_in), .data_in(m3_data_in), .valid_out(merge_to_fifo_valid[3]), .ready_out(fifo_to_merge_ready[3]), .data_out(merge_to_fifo_data[3]));
    assign split_ready[0][2]=m3_ready_in[0]; assign split_ready[1][2]=m3_ready_in[1]; assign split_ready[2][2]=m3_ready_in[2]; assign split_ready[4][3]=m3_ready_in[3];

    // OUTPUT L: from N, S, E, W
    logic [7:0] m4_data_in [0:3]; logic [3:0] m4_valid_in, m4_ready_in;
    assign m4_data_in[0]=split_data[0]; assign m4_data_in[1]=split_data[1]; assign m4_data_in[2]=split_data[2]; assign m4_data_in[3]=split_data[3];
    assign m4_valid_in = {split_valid[3][3], split_valid[2][3], split_valid[1][3], split_valid[0][3]};
    merge_4to1_comb u_merge_4 (.clk(clk), .rst_n(rst_n), .valid_in(m4_valid_in), .ready_in(m4_ready_in), .data_in(m4_data_in), .valid_out(merge_to_fifo_valid[4]), .ready_out(fifo_to_merge_ready[4]), .data_out(merge_to_fifo_data[4]));
    assign split_ready[0][3]=m4_ready_in[0]; assign split_ready[1][3]=m4_ready_in[1]; assign split_ready[2][3]=m4_ready_in[2]; assign split_ready[3][3]=m4_ready_in[3];

    // -------------------------------------------------------------------------
    //  Output FIFOs (5) - the change vs router_with_fifo
    //  Same fifo_sync module as the inputs, just with its own depth parameter.
    // -------------------------------------------------------------------------
    genvar go;
    generate
        for (go = 0; go < 5; go = go + 1) begin : g_output_fifo
            fifo_sync #(.DEPTH(OUT_FIFO_DEPTH), .DATA_WIDTH(8)) u_output_fifo (
                .clk(clk), .rst_n(rst_n),
                .data_in  (merge_to_fifo_data[go]),
                .valid_in (merge_to_fifo_valid[go]),
                .ready_out(fifo_to_merge_ready[go]),
                .data_out (out_data_int[go]),
                .valid_out(out_valid_int[go]),
                .ready_in (out_ready_int[go])
            );
        end
    endgenerate

endmodule


// =============================================================================
//  torus_router_5x5 - wrapper matching the testbench's packed-bus interface.
//
//  FIFO_DEPTH sets the input FIFO depth and is also the default for the output
//  FIFO depth. Override OUT_FIFO_DEPTH separately if you want the two stages
//  sized differently.
// =============================================================================
module torus_router_5x5 #(
    parameter int CURR_X         = 0,
    parameter int CURR_Y         = 0,
    parameter int IN_FIFO_DEPTH     = 16,
    parameter int OUT_FIFO_DEPTH = 16
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

    router_with_fifo_v2 #(
        .IN_FIFO_DEPTH (IN_FIFO_DEPTH),
        .OUT_FIFO_DEPTH(OUT_FIFO_DEPTH)
    ) u_router (
        .clk(clk), .rst_n(rst_n),
        .my_x(CURR_X[1:0]), .my_y(CURR_Y[1:0]),
        .in_valid(in_vld), .in_ready(in_rdy),
        .in_data_0(in_data[0]), .in_data_1(in_data[1]), .in_data_2(in_data[2]),
        .in_data_3(in_data[3]), .in_data_4(in_data[4]),
        .out_valid(out_vld), .out_ready(out_rdy),
        .out_data_0(out_data[0]), .out_data_1(out_data[1]), .out_data_2(out_data[2]),
        .out_data_3(out_data[3]), .out_data_4(out_data[4])
    );

endmodule