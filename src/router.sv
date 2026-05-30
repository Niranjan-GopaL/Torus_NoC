`timescale 1ns/1ps

// =============================================================================
//  5-port torus router (one node of a 4x4 network)
//
//  Flow of a flit through the router:
//    input slice  ->  split (route decode + demux)  ->  merge (arbitrate)  ->  output slice
//
//  A flit is 8 bits. The top nibble is the destination: [7:6]=x, [5:4]=y.
//  Ports use a valid/ready handshake everywhere.
//
//  Port encoding (internal): N=0, S=1, E=2, W=3, L=4   (L = local/this node)
// =============================================================================


// =============================================================================
//  xy_route_logic - decide which output port a flit should leave by
//
//  Reads the destination from the flit, compares it to where we are (my_x/my_y),
//  and picks one of the 5 ports. Three algorithms are selectable via parameter:
//  plain XY, Odd-Even, and a custom torus router.
// =============================================================================
module xy_route_logic #(
    parameter int ROUTING_ALGO = 0   // 0 = XY, 1 = Odd-Even, 2 = Torus
)(
    input  logic [7:0] data_in,
    input  logic [1:0] my_x,
    input  logic [1:0] my_y,
    output logic [2:0] out_port
);

    // Destination coords live in the top nibble of the flit.
    logic [1:0] dst_x = data_in[7:6];
    logic [1:0] dst_y = data_in[5:4];

    localparam PORT_N = 3'd0;
    localparam PORT_S = 3'd1;
    localparam PORT_E = 3'd2;
    localparam PORT_W = 3'd3;
    localparam PORT_L = 3'd4;

generate
    // ---- Plain XY: go fully in X first, then in Y, then you've arrived. ----
    if (ROUTING_ALGO == 0) begin : xy_routing
        always_comb begin
            if      (dst_x > my_x) out_port = PORT_E;
            else if (dst_x < my_x) out_port = PORT_W;
            else if (dst_y > my_y) out_port = PORT_N;
            else if (dst_y < my_y) out_port = PORT_S;
            else                   out_port = PORT_L;   // we're the destination
        end
    end

    // ---- Odd-Even turn model: column parity restricts which turns are legal,
    //      which is what keeps it deadlock-free. ----
    else if (ROUTING_ALGO == 1) begin : oe_routing
        always_comb begin
            if (dst_x == my_x && dst_y == my_y) begin
                out_port = PORT_L;                       // arrived
            end
            else if (my_x[0] == 0) begin                 // even column
                // Even columns: clear out the X distance first, otherwise step in Y.
                if (dst_x != my_x)
                    out_port = (dst_x > my_x) ? PORT_E : PORT_W;
                else
                    out_port = (dst_y > my_y) ? PORT_N : PORT_S;
            end
            else begin                                   // odd column
                // Odd columns: if we're already in the right column, finish in Y;
                // otherwise keep moving in X.
                if (dst_y != my_y && dst_x == my_x)
                    out_port = (dst_y > my_y) ? PORT_N : PORT_S;
                else if (dst_x > my_x) out_port = PORT_E;
                else if (dst_x < my_x) out_port = PORT_W;
                else                   out_port = PORT_L; // unreachable, just in case
            end
        end
    end

    // ---- Custom torus routing (dimension order, X then Y) ----
    //      On a ring, "distance" wraps mod 4. 
    //      We compute the forward distance and pick the shorter way round. 
    //      A distance of 2 is a tie (both ways are equal), 
    //      so what we do is break it by coordinate to avoid creating a cycle.
    else if (ROUTING_ALGO == 2) begin : torus_routing
        logic [1:0] fdx, fdy;   // forward (E/N) ring distance, mod 4

        always_comb begin
            fdx = (dst_x - my_x) & 2'b11;
            fdy = (dst_y - my_y) & 2'b11;

            // X-dim first
            if (fdx != 2'd0) begin                        
                if      (fdx == 2'd1) out_port = PORT_E;  // one step forward
                else if (fdx == 2'd3) out_port = PORT_W;  // one step back (shorter)
                else                  out_port = (my_x < 2'd2) ? PORT_E : PORT_W; // tie
            end
            // then Y-dim
            else if (fdy != 2'd0) begin                  // then Y
                if      (fdy == 2'd1) out_port = PORT_N;
                else if (fdy == 2'd3) out_port = PORT_S;
                else                  out_port = (my_y < 2'd2) ? PORT_N : PORT_S; // tie
            end
            else
                out_port = PORT_L;                        // arrived
        end
    end
endgenerate

endmodule


// =============================================================================
//  valid_ready_slice - a one-deep skid buffer (registered stage)
//
//  Same module is reused at every input and output. It breaks combinational
//  paths: data_out is always the registered value, and ready_out never depends
//  combinationally on ready_in, so handshakes don't ripple through.
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

    // We can take new data if the slot is empty, or it's emptying this cycle.
    assign ready_out = rst_n && (!data_valid || ready_in);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_valid <= 1'b0;
            data_reg   <= 8'h00;
        end else begin
            if (valid_in && ready_out)        data_valid <= 1'b1;   // load
            else if (data_valid && ready_in)  data_valid <= 1'b0;   // drain
            if (valid_in && ready_out)        data_reg   <= data_in;
        end
    end

    assign valid_out = data_valid;
    assign data_out  = data_reg;

endmodule


// =============================================================================
//  split_1to4_simple - route a flit, then send it out one of 4 ports
//
//  Asks xy_route_logic where the flit should go, then maps that to one of the
//  four non-self outputs (a flit never leaves the way it came in, so each input
//  has a different "exclude" map).
// =============================================================================
module split_1to4_simple #(
    parameter int INPUT_PORT   = 0,
    parameter int ROUTING_ALGO = 0
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

    logic [2:0] global_port;   // 0..4, the chosen direction
    logic [1:0] dest_index;    // 0..3, which of our 4 outputs that maps to

    xy_route_logic #(.ROUTING_ALGO(ROUTING_ALGO)) u_xy (
        .data_in(data_in), .my_x(my_x), .my_y(my_y), .out_port(global_port)
    );

    always_comb begin
        valid_out  = 4'b0000;
        ready_in   = 1'b0;
        dest_index = 2'd0;

        // Each input drops its own direction from the list, so the remaining
        // four directions pack down into output indices 0..3.
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

    assign data_out = data_in;   // we route, we don't modify

endmodule


// =============================================================================
//  merge_4to1_comb - 4-to-1 merge with round-robin arbitration
//
//  Four inputs compete for one output. Round-robin keeps it fair: a 'mask'
//  remembers who has already been served this round, so everyone gets a turn
//  before anyone gets a second one. Losers just hold their request, which
//  naturally pushes backpressure upstream.
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

    logic [NUM_PORTS-1:0]         mask;            // who's still eligible this round
    logic [NUM_PORTS-1:0]         masked_req;
    logic [NUM_PORTS-1:0]         unmasked_grant;
    logic [NUM_PORTS-1:0]         grant;
    logic [$clog2(NUM_PORTS)-1:0] selected_port;

    // Requests still eligible this round, and the fallback if none are.
    // (x & -x) isolates the lowest set bit, i.e. a simple priority pick.
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

    // After a grant, drop that port from the mask. When the mask empties (or we
    // had to use the fallback), start a fresh round.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mask <= {NUM_PORTS{1'b1}};
        else if (valid_out && ready_out && |grant)
            mask <= (|masked_req) ? (mask & ~grant) : ({NUM_PORTS{1'b1}} & ~grant);
    end

endmodule


// =============================================================================
//  router_simple - the full router
//
//  5 input slices  ->  5 splits  ->  5 round-robin merges  ->  5 output slices.
//  Each merge collects the four splits that can target its direction.
//
//  The testbench numbers ports [LOCAL, EAST, WEST, NORTH, SOUTH], but internally
//  we use [N, S, E, W, L]. The first thing we do is remap between the two.
// =============================================================================
module router_simple #(
    parameter int ROUTING_ALGO = 0
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

    // External outputs - same [LOCAL, EAST, WEST, NORTH, SOUTH] order
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
        // inputs: pull each internal port from its testbench counterpart
        in_valid_int[0] = in_valid[3];  in_data_int[0] = in_data_3;  // N
        in_valid_int[1] = in_valid[4];  in_data_int[1] = in_data_4;  // S
        in_valid_int[2] = in_valid[1];  in_data_int[2] = in_data_1;  // E
        in_valid_int[3] = in_valid[2];  in_data_int[3] = in_data_2;  // W
        in_valid_int[4] = in_valid[0];  in_data_int[4] = in_data_0;  // L
    end

    always_comb begin
        // outputs: push each internal port back out to its testbench slot
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
    logic [7:0] slice_to_split_data  [4:0];   // input slice -> split
    logic [4:0] slice_to_split_valid;
    logic [4:0] split_to_slice_ready;

    logic [3:0] split_valid [4:0];            // split -> merge (4 outs per split)
    logic [3:0] split_ready [4:0];
    logic [7:0] split_data  [4:0];

    logic [7:0] merge_to_slice_data  [4:0];   // merge -> output slice
    logic [4:0] merge_to_slice_valid;
    logic [4:0] slice_to_merge_ready;

    // -------------------------------------------------------------------------
    //  Input slices (5)
    // -------------------------------------------------------------------------
    genvar gi;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : g_input_slice
            valid_ready_slice u_input_slice (
                .clk(clk), .rst_n(rst_n),
                .data_in  (in_data_int[gi]),
                .valid_in (in_valid_int[gi]),
                .ready_out(in_ready_int[gi]),
                .data_out (slice_to_split_data[gi]),
                .valid_out(slice_to_split_valid[gi]),
                .ready_in (split_to_slice_ready[gi])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    //  Splits (5) - one per input direction
    // -------------------------------------------------------------------------
    split_1to4_simple #(.INPUT_PORT(0), .ROUTING_ALGO(ROUTING_ALGO)) u_split_0 (
        .valid_in(slice_to_split_valid[0]), .data_in(slice_to_split_data[0]), .ready_in(split_to_slice_ready[0]),
        .my_x(my_x), .my_y(my_y), .valid_out(split_valid[0]), .data_out(split_data[0]), .ready_out(split_ready[0]));
    split_1to4_simple #(.INPUT_PORT(1), .ROUTING_ALGO(ROUTING_ALGO)) u_split_1 (
        .valid_in(slice_to_split_valid[1]), .data_in(slice_to_split_data[1]), .ready_in(split_to_slice_ready[1]),
        .my_x(my_x), .my_y(my_y), .valid_out(split_valid[1]), .data_out(split_data[1]), .ready_out(split_ready[1]));
    split_1to4_simple #(.INPUT_PORT(2), .ROUTING_ALGO(ROUTING_ALGO)) u_split_2 (
        .valid_in(slice_to_split_valid[2]), .data_in(slice_to_split_data[2]), .ready_in(split_to_slice_ready[2]),
        .my_x(my_x), .my_y(my_y), .valid_out(split_valid[2]), .data_out(split_data[2]), .ready_out(split_ready[2]));
    split_1to4_simple #(.INPUT_PORT(3), .ROUTING_ALGO(ROUTING_ALGO)) u_split_3 (
        .valid_in(slice_to_split_valid[3]), .data_in(slice_to_split_data[3]), .ready_in(split_to_slice_ready[3]),
        .my_x(my_x), .my_y(my_y), .valid_out(split_valid[3]), .data_out(split_data[3]), .ready_out(split_ready[3]));
    split_1to4_simple #(.INPUT_PORT(4), .ROUTING_ALGO(ROUTING_ALGO)) u_split_4 (
        .valid_in(slice_to_split_valid[4]), .data_in(slice_to_split_data[4]), .ready_in(split_to_slice_ready[4]),
        .my_x(my_x), .my_y(my_y), .valid_out(split_valid[4]), .data_out(split_data[4]), .ready_out(split_ready[4]));

    // -------------------------------------------------------------------------
    //  Merges (5) - one per output direction
    //
    //  Each output gathers the four splits that can aim at it (every direction
    //  except itself). The split_ready hookups close the backpressure loop.
    // -------------------------------------------------------------------------

    // OUTPUT N: from S, E, W, L
    logic [7:0] m0_data_in [0:3]; logic [3:0] m0_valid_in, m0_ready_in;
    assign m0_data_in[0]=split_data[1]; assign m0_data_in[1]=split_data[2]; assign m0_data_in[2]=split_data[3]; assign m0_data_in[3]=split_data[4];
    assign m0_valid_in = {split_valid[4][0], split_valid[3][0], split_valid[2][0], split_valid[1][0]};
    merge_4to1_comb u_merge_0 (.clk(clk), .rst_n(rst_n), .valid_in(m0_valid_in), .ready_in(m0_ready_in), .data_in(m0_data_in),
        .valid_out(merge_to_slice_valid[0]), .ready_out(slice_to_merge_ready[0]), .data_out(merge_to_slice_data[0]));
    assign split_ready[1][0]=m0_ready_in[0]; assign split_ready[2][0]=m0_ready_in[1]; assign split_ready[3][0]=m0_ready_in[2]; assign split_ready[4][0]=m0_ready_in[3];

    // OUTPUT S: from N, E, W, L
    logic [7:0] m1_data_in [0:3]; logic [3:0] m1_valid_in, m1_ready_in;
    assign m1_data_in[0]=split_data[0]; assign m1_data_in[1]=split_data[2]; assign m1_data_in[2]=split_data[3]; assign m1_data_in[3]=split_data[4];
    assign m1_valid_in = {split_valid[4][1], split_valid[3][1], split_valid[2][1], split_valid[0][0]};
    merge_4to1_comb u_merge_1 (.clk(clk), .rst_n(rst_n), .valid_in(m1_valid_in), .ready_in(m1_ready_in), .data_in(m1_data_in),
        .valid_out(merge_to_slice_valid[1]), .ready_out(slice_to_merge_ready[1]), .data_out(merge_to_slice_data[1]));
    assign split_ready[0][0]=m1_ready_in[0]; assign split_ready[2][1]=m1_ready_in[1]; assign split_ready[3][1]=m1_ready_in[2]; assign split_ready[4][1]=m1_ready_in[3];

    // OUTPUT E: from N, S, W, L
    logic [7:0] m2_data_in [0:3]; logic [3:0] m2_valid_in, m2_ready_in;
    assign m2_data_in[0]=split_data[0]; assign m2_data_in[1]=split_data[1]; assign m2_data_in[2]=split_data[3]; assign m2_data_in[3]=split_data[4];
    assign m2_valid_in = {split_valid[4][2], split_valid[3][2], split_valid[1][1], split_valid[0][1]};
    merge_4to1_comb u_merge_2 (.clk(clk), .rst_n(rst_n), .valid_in(m2_valid_in), .ready_in(m2_ready_in), .data_in(m2_data_in),
        .valid_out(merge_to_slice_valid[2]), .ready_out(slice_to_merge_ready[2]), .data_out(merge_to_slice_data[2]));
    assign split_ready[0][1]=m2_ready_in[0]; assign split_ready[1][1]=m2_ready_in[1]; assign split_ready[3][2]=m2_ready_in[2]; assign split_ready[4][2]=m2_ready_in[3];

    // OUTPUT W: from N, S, E, L
    logic [7:0] m3_data_in [0:3]; logic [3:0] m3_valid_in, m3_ready_in;
    assign m3_data_in[0]=split_data[0]; assign m3_data_in[1]=split_data[1]; assign m3_data_in[2]=split_data[2]; assign m3_data_in[3]=split_data[4];
    assign m3_valid_in = {split_valid[4][3], split_valid[2][2], split_valid[1][2], split_valid[0][2]};
    merge_4to1_comb u_merge_3 (.clk(clk), .rst_n(rst_n), .valid_in(m3_valid_in), .ready_in(m3_ready_in), .data_in(m3_data_in),
        .valid_out(merge_to_slice_valid[3]), .ready_out(slice_to_merge_ready[3]), .data_out(merge_to_slice_data[3]));
    assign split_ready[0][2]=m3_ready_in[0]; assign split_ready[1][2]=m3_ready_in[1]; assign split_ready[2][2]=m3_ready_in[2]; assign split_ready[4][3]=m3_ready_in[3];

    // OUTPUT L: from N, S, E, W
    logic [7:0] m4_data_in [0:3]; logic [3:0] m4_valid_in, m4_ready_in;
    assign m4_data_in[0]=split_data[0]; assign m4_data_in[1]=split_data[1]; assign m4_data_in[2]=split_data[2]; assign m4_data_in[3]=split_data[3];
    assign m4_valid_in = {split_valid[3][3], split_valid[2][3], split_valid[1][3], split_valid[0][3]};
    merge_4to1_comb u_merge_4 (.clk(clk), .rst_n(rst_n), .valid_in(m4_valid_in), .ready_in(m4_ready_in), .data_in(m4_data_in),
        .valid_out(merge_to_slice_valid[4]), .ready_out(slice_to_merge_ready[4]), .data_out(merge_to_slice_data[4]));
    assign split_ready[0][3]=m4_ready_in[0]; assign split_ready[1][3]=m4_ready_in[1]; assign split_ready[2][3]=m4_ready_in[2]; assign split_ready[3][3]=m4_ready_in[3];

    // -------------------------------------------------------------------------
    //  Output slices (5) - same slice module as the inputs
    // -------------------------------------------------------------------------
    genvar go;
    generate
        for (go = 0; go < 5; go = go + 1) begin : g_output_slice
            valid_ready_slice u_output_slice (
                .clk(clk), .rst_n(rst_n),
                .data_in  (merge_to_slice_data[go]),
                .valid_in (merge_to_slice_valid[go]),
                .ready_out(slice_to_merge_ready[go]),
                .data_out (out_data_int[go]),
                .valid_out(out_valid_int[go]),
                .ready_in (out_ready_int[go])
            );
        end
    endgenerate

endmodule


// =============================================================================
//  torus_router_5x5 - thin wrapper that matches the testbench's port shape
//  (packed [4:0][7:0] buses) and feeds router_simple.
// =============================================================================
module torus_router_5x5 #(
    parameter int CURR_X       = 0,
    parameter int CURR_Y       = 0,
    parameter int ROUTING_ALGO = 2
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

    router_simple #(.ROUTING_ALGO(ROUTING_ALGO)) u_router (
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