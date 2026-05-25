`timescale 1ns/1ps

// XY ROUTE LOGIC
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




module input_valid_ready_slice (

    input  logic        clk,
    input  logic        rst_n,

    input  logic [7:0]  pkt_data_in,
    input  logic        pkt_valid_in,
    output logic        pkt_ready_out,
    
    output logic [7:0]  split_data_out,
    output logic        split_valid_out,
    input  logic        split_ready_in
);

    // Internal registers
    logic        data_valid;
    logic [7:0]  data_reg;

    // Ready when: no valid data stored OR downstream can accept
    assign pkt_ready_out = (!rst_n) ? 1'b0 : !data_valid || split_ready_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_valid <= 1'b0;
            data_reg   <= 8'h00;
        end else if (pkt_valid_in && pkt_ready_out) begin
            // Store incoming data on successful handshake
            data_valid <= 1'b1;
            data_reg   <= pkt_data_in;
        end else if (data_valid && split_ready_in) begin
            // Data consumed by downstream, clear valid
            data_valid <= 1'b0;
        end
    end

    // Valid when: holding data OR new data arriving this cycle
    assign split_valid_out = data_valid || (pkt_valid_in && pkt_ready_out);
    
    // Data out: stored data if valid, otherwise incoming data
    assign split_data_out = data_valid ? data_reg : pkt_data_in;

endmodule




// SPLIT 1-to-4
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

        valid_out = 4'b0000;
        ready_in  = 1'b0;
        dest_index = 2'd0;

        case(INPUT_PORT)

            // N excludes N
            0: begin
                case(global_port)
                    1: dest_index = 0;
                    2: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

            // S excludes S
            1: begin
                case(global_port)
                    0: dest_index = 0;
                    2: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

            // E excludes E
            2: begin
                case(global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    3: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

            // W excludes W
            3: begin
                case(global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    2: dest_index = 2;
                    4: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

            // LOCAL excludes LOCAL
            4: begin
                case(global_port)
                    0: dest_index = 0;
                    1: dest_index = 1;
                    2: dest_index = 2;
                    3: dest_index = 3;
                    default: dest_index = 0;
                endcase
            end

        endcase

        if(valid_in)
            valid_out[dest_index] = 1'b1;

        ready_in = ready_out[dest_index];

    end

    assign data_out = data_in;

endmodule



// MERGE 4-to-1
module merge_4to1_simple (

    input  logic [3:0] valid_in,

    input  logic [7:0] data_in_0,
    input  logic [7:0] data_in_1,
    input  logic [7:0] data_in_2,
    input  logic [7:0] data_in_3,

    output logic [3:0] ready_in,

    output logic       valid_out,
    output logic [7:0] data_out,

    input  logic       ready_out
);

    always_comb begin

        valid_out = 0;
        data_out  = 0;
        ready_in  = 4'b0000;

        // Priority: highest index first (round-robin or priority can be changed)
        if(valid_in[3]) begin
            valid_out   = 1;
            data_out    = data_in_3;
            ready_in[3] = ready_out;
        end

        else if(valid_in[2]) begin
            valid_out   = 1;
            data_out    = data_in_2;
            ready_in[2] = ready_out;
        end

        else if(valid_in[1]) begin
            valid_out   = 1;
            data_out    = data_in_1;
            ready_in[1] = ready_out;
        end

        else if(valid_in[0]) begin
            valid_out   = 1;
            data_out    = data_in_0;
            ready_in[0] = ready_out;
        end

    end

endmodule




module output_valid_ready_slice (

    input  logic        clk,
    input  logic        rst_n,

    input  logic [7:0]  merge_data_in,
    input  logic        merge_valid_in,
    output logic        merge_ready_out,
    
    output logic [7:0]  pkt_data_out,
    output logic        pkt_valid_out,
    input  logic        pkt_ready_in
);

    // Internal registers
    logic        data_valid;
    logic [7:0]  data_reg;

    // Ready when: no data stored OR downstream can accept
    assign merge_ready_out = (!rst_n) ? 1'b0 : !data_valid || pkt_ready_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_valid <= 1'b0;
            data_reg   <= 8'h00;
        end else if (merge_valid_in && merge_ready_out) begin
            // Store incoming data on successful handshake
            data_valid <= 1'b1;
            data_reg   <= merge_data_in;
        end else if (data_valid && pkt_ready_in) begin
            // Data consumed by downstream, clear valid
            data_valid <= 1'b0;
        end
    end

    // Valid when: holding data OR new data arriving this cycle
    assign pkt_valid_out = data_valid || (merge_valid_in && merge_ready_out);
    
    // Data out: stored data if valid, otherwise incoming data
    assign pkt_data_out = data_valid ? data_reg : merge_data_in;
    
endmodule



// =============================================================================
// ROUTER TOP
// =============================================================================
// Port ordering: [LOCAL, EAST, WEST, NORTH, SOUTH] to match testbench
// =============================================================================
module router_simple (

    input  logic        clk,
    input  logic        rst_n,

    input  logic [1:0]  my_x,
    input  logic [1:0]  my_y,

    // Input ports (from previous router or source node)
    // Order: [LOCAL, EAST, WEST, NORTH, SOUTH]
    input  logic [4:0]  in_valid,
    input  logic [7:0]  in_data_0,  // LOCAL
    input  logic [7:0]  in_data_1,  // EAST
    input  logic [7:0]  in_data_2,  // WEST
    input  logic [7:0]  in_data_3,  // NORTH
    input  logic [7:0]  in_data_4,  // SOUTH
    output logic [4:0]  in_ready,

    // Output ports (to next router or destination node)
    // Order: [LOCAL, EAST, WEST, NORTH, SOUTH]
    output logic [4:0]  out_valid,
    output logic [7:0]  out_data_0,  // LOCAL
    output logic [7:0]  out_data_1,  // EAST
    output logic [7:0]  out_data_2,  // WEST
    output logic [7:0]  out_data_3,  // NORTH
    output logic [7:0]  out_data_4,  // SOUTH
    input  logic [4:0]  out_ready
);

    // =========================================================================
    // Port mapping between testbench order [L,E,W,N,S] and router internal [N,S,E,W,L]
    // =========================================================================

    // Internal mapping (router expects [N,S,E,W,L])
    logic [4:0] in_valid_int;
    logic [4:0] in_ready_int;
    logic [7:0] in_data_int [4:0];
    
    logic [4:0] out_valid_int;
    logic [4:0] out_ready_int;
    logic [7:0] out_data_int [4:0];
    
    // Map inputs: testbench [L,E,W,N,S] -> internal [N,S,E,W,L]
    always_comb begin
        in_valid_int[0] = in_valid[3];  // PORT_N gets testbench NORTH
        in_valid_int[1] = in_valid[4];  // PORT_S gets testbench SOUTH
        in_valid_int[2] = in_valid[1];  // PORT_E gets testbench EAST
        in_valid_int[3] = in_valid[2];  // PORT_W gets testbench WEST
        in_valid_int[4] = in_valid[0];  // PORT_L gets testbench LOCAL
        
        in_data_int[0] = in_data_3;     // NORTH data
        in_data_int[1] = in_data_4;     // SOUTH data
        in_data_int[2] = in_data_1;     // EAST data
        in_data_int[3] = in_data_2;     // WEST data
        in_data_int[4] = in_data_0;     // LOCAL data
    end
    
    // Map outputs: internal [N,S,E,W,L] -> testbench [L,E,W,N,S]
    always_comb begin
        out_valid[0] = out_valid_int[4];  // LOCAL gets PORT_L
        out_valid[1] = out_valid_int[2];  // EAST  gets PORT_E
        out_valid[2] = out_valid_int[3];  // WEST  gets PORT_W
        out_valid[3] = out_valid_int[0];  // NORTH gets PORT_N
        out_valid[4] = out_valid_int[1];  // SOUTH gets PORT_S
        
        out_data_0 = out_data_int[4];     // LOCAL data
        out_data_1 = out_data_int[2];     // EAST data
        out_data_2 = out_data_int[3];     // WEST data
        out_data_3 = out_data_int[0];     // NORTH data
        out_data_4 = out_data_int[1];     // SOUTH data
        
        // Map ready signals (reverse direction)
        out_ready_int[4] = out_ready[0];  // PORT_L ready from LOCAL
        out_ready_int[2] = out_ready[1];  // PORT_E ready from EAST
        out_ready_int[3] = out_ready[2];  // PORT_W ready from WEST
        out_ready_int[0] = out_ready[3];  // PORT_N ready from NORTH
        out_ready_int[1] = out_ready[4];  // PORT_S ready from SOUTH
        
        // Map in_ready back
        in_ready[3] = in_ready_int[0];    // NORTH gets PORT_N ready
        in_ready[4] = in_ready_int[1];    // SOUTH gets PORT_S ready
        in_ready[1] = in_ready_int[2];    // EAST  gets PORT_E ready
        in_ready[2] = in_ready_int[3];    // WEST  gets PORT_W ready
        in_ready[0] = in_ready_int[4];    // LOCAL gets PORT_L ready
    end


    // =========================================================================
    // INPUT SLICE -> SPLIT signals
    // =========================================================================
    
    logic [7:0] slice_to_split_data_0;
    logic [7:0] slice_to_split_data_1;
    logic [7:0] slice_to_split_data_2;
    logic [7:0] slice_to_split_data_3;
    logic [7:0] slice_to_split_data_4;

    logic slice_to_split_valid_0;
    logic slice_to_split_valid_1;
    logic slice_to_split_valid_2;
    logic slice_to_split_valid_3;
    logic slice_to_split_valid_4;

    logic split_to_slice_ready_0;
    logic split_to_slice_ready_1;
    logic split_to_slice_ready_2;
    logic split_to_slice_ready_3;
    logic split_to_slice_ready_4;

    // =========================================================================
    // SPLIT -> MERGE signals
    // =========================================================================

    logic [3:0] split_valid_0;
    logic [3:0] split_valid_1;
    logic [3:0] split_valid_2;
    logic [3:0] split_valid_3;
    logic [3:0] split_valid_4;

    logic [3:0] split_ready_0;
    logic [3:0] split_ready_1;
    logic [3:0] split_ready_2;
    logic [3:0] split_ready_3;
    logic [3:0] split_ready_4;

    logic [7:0] split_data_0;
    logic [7:0] split_data_1;
    logic [7:0] split_data_2;
    logic [7:0] split_data_3;
    logic [7:0] split_data_4;

    // =========================================================================
    // MERGE -> OUTPUT SLICE signals
    // =========================================================================

    logic [7:0] merge_to_slice_data_0;
    logic [7:0] merge_to_slice_data_1;
    logic [7:0] merge_to_slice_data_2;
    logic [7:0] merge_to_slice_data_3;
    logic [7:0] merge_to_slice_data_4;

    logic merge_to_slice_valid_0;
    logic merge_to_slice_valid_1;
    logic merge_to_slice_valid_2;
    logic merge_to_slice_valid_3;
    logic merge_to_slice_valid_4;

    logic slice_to_merge_ready_0;
    logic slice_to_merge_ready_1;
    logic slice_to_merge_ready_2;
    logic slice_to_merge_ready_3;
    logic slice_to_merge_ready_4;

    // =========================================================================
    // INPUT VALID/READY SLICES (5 instances, one per input port)
    // =========================================================================

    input_valid_ready_slice u_input_slice_0 (
        .clk             (clk),
        .rst_n           (rst_n),
        .pkt_data_in     (in_data_int[0]),
        .pkt_valid_in    (in_valid_int[0]),
        .pkt_ready_out   (in_ready_int[0]),
        .split_data_out  (slice_to_split_data_0),
        .split_valid_out (slice_to_split_valid_0),
        .split_ready_in  (split_to_slice_ready_0)
    );

    input_valid_ready_slice u_input_slice_1 (
        .clk             (clk),
        .rst_n           (rst_n),
        .pkt_data_in     (in_data_int[1]),
        .pkt_valid_in    (in_valid_int[1]),
        .pkt_ready_out   (in_ready_int[1]),
        .split_data_out  (slice_to_split_data_1),
        .split_valid_out (slice_to_split_valid_1),
        .split_ready_in  (split_to_slice_ready_1)
    );

    input_valid_ready_slice u_input_slice_2 (
        .clk             (clk),
        .rst_n           (rst_n),
        .pkt_data_in     (in_data_int[2]),
        .pkt_valid_in    (in_valid_int[2]),
        .pkt_ready_out   (in_ready_int[2]),
        .split_data_out  (slice_to_split_data_2),
        .split_valid_out (slice_to_split_valid_2),
        .split_ready_in  (split_to_slice_ready_2)
    );

    input_valid_ready_slice u_input_slice_3 (
        .clk             (clk),
        .rst_n           (rst_n),
        .pkt_data_in     (in_data_int[3]),
        .pkt_valid_in    (in_valid_int[3]),
        .pkt_ready_out   (in_ready_int[3]),
        .split_data_out  (slice_to_split_data_3),
        .split_valid_out (slice_to_split_valid_3),
        .split_ready_in  (split_to_slice_ready_3)
    );

    input_valid_ready_slice u_input_slice_4 (
        .clk             (clk),
        .rst_n           (rst_n),
        .pkt_data_in     (in_data_int[4]),
        .pkt_valid_in    (in_valid_int[4]),
        .pkt_ready_out   (in_ready_int[4]),
        .split_data_out  (slice_to_split_data_4),
        .split_valid_out (slice_to_split_valid_4),
        .split_ready_in  (split_to_slice_ready_4)
    );

    // =========================================================================
    // SPLITS (5 instances, one per input port)
    // =========================================================================

    split_1to4_simple #(.INPUT_PORT(0)) u_split_0 (
        .valid_in  (slice_to_split_valid_0),
        .data_in   (slice_to_split_data_0),
        .ready_in  (split_to_slice_ready_0),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid_0),
        .data_out  (split_data_0),
        .ready_out (split_ready_0)
    );

    split_1to4_simple #(.INPUT_PORT(1)) u_split_1 (
        .valid_in  (slice_to_split_valid_1),
        .data_in   (slice_to_split_data_1),
        .ready_in  (split_to_slice_ready_1),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid_1),
        .data_out  (split_data_1),
        .ready_out (split_ready_1)
    );

    split_1to4_simple #(.INPUT_PORT(2)) u_split_2 (
        .valid_in  (slice_to_split_valid_2),
        .data_in   (slice_to_split_data_2),
        .ready_in  (split_to_slice_ready_2),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid_2),
        .data_out  (split_data_2),
        .ready_out (split_ready_2)
    );

    split_1to4_simple #(.INPUT_PORT(3)) u_split_3 (
        .valid_in  (slice_to_split_valid_3),
        .data_in   (slice_to_split_data_3),
        .ready_in  (split_to_slice_ready_3),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid_3),
        .data_out  (split_data_3),
        .ready_out (split_ready_3)
    );

    split_1to4_simple #(.INPUT_PORT(4)) u_split_4 (
        .valid_in  (slice_to_split_valid_4),
        .data_in   (slice_to_split_data_4),
        .ready_in  (split_to_slice_ready_4),
        .my_x      (my_x),
        .my_y      (my_y),
        .valid_out (split_valid_4),
        .data_out  (split_data_4),
        .ready_out (split_ready_4)
    );

    // =========================================================================
    // MERGES (5 instances, one per output port)
    // =========================================================================

    // OUTPUT N (index 0)
    merge_4to1_simple u_merge_0 (

        .valid_in ({
            split_valid_4[0],
            split_valid_3[0],
            split_valid_2[0],
            split_valid_1[0]
        }),

        .data_in_0 (split_data_1),
        .data_in_1 (split_data_2),
        .data_in_2 (split_data_3),
        .data_in_3 (split_data_4),

        .ready_in ({
            split_ready_4[0],
            split_ready_3[0],
            split_ready_2[0],
            split_ready_1[0]
        }),

        .valid_out (merge_to_slice_valid_0),
        .data_out  (merge_to_slice_data_0),

        .ready_out (slice_to_merge_ready_0)
    );

    // OUTPUT S (index 1)
    merge_4to1_simple u_merge_1 (

        .valid_in ({
            split_valid_4[1],
            split_valid_3[1],
            split_valid_2[1],
            split_valid_0[0]
        }),

        .data_in_0 (split_data_0),
        .data_in_1 (split_data_2),
        .data_in_2 (split_data_3),
        .data_in_3 (split_data_4),

        .ready_in ({
            split_ready_4[1],
            split_ready_3[1],
            split_ready_2[1],
            split_ready_0[0]
        }),

        .valid_out (merge_to_slice_valid_1),
        .data_out  (merge_to_slice_data_1),

        .ready_out (slice_to_merge_ready_1)
    );

    // OUTPUT E (index 2)
    merge_4to1_simple u_merge_2 (

        .valid_in ({
            split_valid_4[2],
            split_valid_3[2],
            split_valid_1[1],
            split_valid_0[1]
        }),

        .data_in_0 (split_data_0),
        .data_in_1 (split_data_1),
        .data_in_2 (split_data_3),
        .data_in_3 (split_data_4),

        .ready_in ({
            split_ready_4[2],
            split_ready_3[2],
            split_ready_1[1],
            split_ready_0[1]
        }),

        .valid_out (merge_to_slice_valid_2),
        .data_out  (merge_to_slice_data_2),

        .ready_out (slice_to_merge_ready_2)
    );

    // OUTPUT W (index 3)
    merge_4to1_simple u_merge_3 (

        .valid_in ({
            split_valid_4[3],
            split_valid_2[2],
            split_valid_1[2],
            split_valid_0[2]
        }),

        .data_in_0 (split_data_0),
        .data_in_1 (split_data_1),
        .data_in_2 (split_data_2),
        .data_in_3 (split_data_4),

        .ready_in ({
            split_ready_4[3],
            split_ready_2[2],
            split_ready_1[2],
            split_ready_0[2]
        }),

        .valid_out (merge_to_slice_valid_3),
        .data_out  (merge_to_slice_data_3),

        .ready_out (slice_to_merge_ready_3)
    );

    // OUTPUT L (index 4)
    merge_4to1_simple u_merge_4 (

        .valid_in ({
            split_valid_3[3],
            split_valid_2[3],
            split_valid_1[3],
            split_valid_0[3]
        }),

        .data_in_0 (split_data_0),
        .data_in_1 (split_data_1),
        .data_in_2 (split_data_2),
        .data_in_3 (split_data_3),

        .ready_in ({
            split_ready_3[3],
            split_ready_2[3],
            split_ready_1[3],
            split_ready_0[3]
        }),

        .valid_out (merge_to_slice_valid_4),
        .data_out  (merge_to_slice_data_4),

        .ready_out (slice_to_merge_ready_4)
    );

    // =========================================================================
    // OUTPUT VALID/READY SLICES (5 instances, one per output port)
    // =========================================================================

    output_valid_ready_slice u_output_slice_0 (
        .clk              (clk),
        .rst_n            (rst_n),
        .merge_data_in    (merge_to_slice_data_0),
        .merge_valid_in   (merge_to_slice_valid_0),
        .merge_ready_out  (slice_to_merge_ready_0),
        .pkt_data_out     (out_data_int[0]),
        .pkt_valid_out    (out_valid_int[0]),
        .pkt_ready_in     (out_ready_int[0])
    );

    output_valid_ready_slice u_output_slice_1 (
        .clk              (clk),
        .rst_n            (rst_n),
        .merge_data_in    (merge_to_slice_data_1),
        .merge_valid_in   (merge_to_slice_valid_1),
        .merge_ready_out  (slice_to_merge_ready_1),
        .pkt_data_out     (out_data_int[1]),
        .pkt_valid_out    (out_valid_int[1]),
        .pkt_ready_in     (out_ready_int[1])
    );

    output_valid_ready_slice u_output_slice_2 (
        .clk              (clk),
        .rst_n            (rst_n),
        .merge_data_in    (merge_to_slice_data_2),
        .merge_valid_in   (merge_to_slice_valid_2),
        .merge_ready_out  (slice_to_merge_ready_2),
        .pkt_data_out     (out_data_int[2]),
        .pkt_valid_out    (out_valid_int[2]),
        .pkt_ready_in     (out_ready_int[2])
    );

    output_valid_ready_slice u_output_slice_3 (
        .clk              (clk),
        .rst_n            (rst_n),
        .merge_data_in    (merge_to_slice_data_3),
        .merge_valid_in   (merge_to_slice_valid_3),
        .merge_ready_out  (slice_to_merge_ready_3),
        .pkt_data_out     (out_data_int[3]),
        .pkt_valid_out    (out_valid_int[3]),
        .pkt_ready_in     (out_ready_int[3])
    );

    output_valid_ready_slice u_output_slice_4 (
        .clk              (clk),
        .rst_n            (rst_n),
        .merge_data_in    (merge_to_slice_data_4),
        .merge_valid_in   (merge_to_slice_valid_4),
        .merge_ready_out  (slice_to_merge_ready_4),
        .pkt_data_out     (out_data_int[4]),
        .pkt_valid_out    (out_valid_int[4]),
        .pkt_ready_in     (out_ready_int[4])
    );

endmodule




module torus_router_5x5 #(
    parameter int CURR_X = 0,
    parameter int CURR_Y = 0
)(
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic [4:0]  in_vld,
    output logic [4:0]  in_rdy,
    input  logic [4:0][7:0] in_data,
    
    output logic [4:0]  out_vld,
    input  logic [4:0]  out_rdy,
    output logic [4:0][7:0] out_data
);

    // Testbench port mapping (as defined in tb):
    // LOCAL  = 0
    // EAST   = 1
    // WEST   = 2
    // NORTH  = 3
    // SOUTH  = 4
    
    // Router_simple port mapping:
    // The router_simple expects ports in order: [LOCAL, EAST, WEST, NORTH, SOUTH]
    // But internally it maps to [N, S, E, W, L]
    // So we can directly connect without remapping if we instantiate correctly
    
    // Instantiate router_simple with direct connection
    // The router_simple already has the correct port ordering [LOCAL, EAST, WEST, NORTH, SOUTH]
    router_simple u_router (
        .clk         (clk),
        .rst_n       (rst_n),
        .my_x        (CURR_X[1:0]),
        .my_y        (CURR_Y[1:0]),
        
        // Input ports - direct connection (testbench order matches router_simple)
        .in_valid    (in_vld),
        .in_ready    (in_rdy),
        .in_data_0   (in_data[0]),  // LOCAL
        .in_data_1   (in_data[1]),  // EAST
        .in_data_2   (in_data[2]),  // WEST
        .in_data_3   (in_data[3]),  // NORTH
        .in_data_4   (in_data[4]),  // SOUTH
        
        // Output ports - direct connection
        .out_valid   (out_vld),
        .out_ready   (out_rdy),
        .out_data_0  (out_data[0]),  // LOCAL
        .out_data_1  (out_data[1]),  // EAST
        .out_data_2  (out_data[2]),  // WEST
        .out_data_3  (out_data[3]),  // NORTH
        .out_data_4  (out_data[4])   // SOUTH
    );

endmodule