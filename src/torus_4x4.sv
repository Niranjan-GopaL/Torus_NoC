`timescale 1ns/1ps

// =============================================================================
// torus_4x4 — 4x4 Torus Topology built from torus_router_5x5
//
// Node indexing : ID = y*4 + x   (x,y in 0..3)
//
// Per-router port order (matches torus_router_5x5):
//   [0] LOCAL
//   [1] EAST
//   [2] WEST
//   [3] NORTH
//   [4] SOUTH
//
// Torus wrap-around links:
//   East  of (x,y) connects to West  of ((x+1)%4, y)
//   West  of (x,y) connects to East  of ((x-1)%4, y)
//   North of (x,y) connects to South of (x, (y+1)%4)
//   South of (x,y) connects to North of (x, (y-1)%4)
// =============================================================================
module torus_4x4 #(
    parameter int FIFO_DEPTH = 64
)(
    input  logic              clk,
    input  logic              rst_n,

    // Local injection ports (one per node)
    input  logic [15:0]       local_in_vld,
    output logic [15:0]       local_in_rdy,
    input  logic [15:0][7:0]  local_in_data,

    // Local ejection ports (one per node)
    output logic [15:0]       local_out_vld,
    input  logic [15:0]       local_out_rdy,
    output logic [15:0][7:0]  local_out_data
);

    // -------------------------------------------------------------------------
    // Per-router signal bundles
    // -------------------------------------------------------------------------
    logic [4:0]      rtr_in_vld   [0:15];
    logic [4:0]      rtr_in_rdy   [0:15];
    logic [4:0][7:0] rtr_in_data  [0:15];

    logic [4:0]      rtr_out_vld  [0:15];
    logic [4:0]      rtr_out_rdy  [0:15];
    logic [4:0][7:0] rtr_out_data [0:15];

    // Port index constants
    localparam int LOCAL = 0;
    localparam int EAST  = 1;
    localparam int WEST  = 2;
    localparam int NORTH = 3;
    localparam int SOUTH = 4;

    // -------------------------------------------------------------------------
    // Instantiate 16 routers
    // -------------------------------------------------------------------------
    genvar gx, gy;
    generate
        for (gy = 0; gy < 4; gy = gy + 1) begin : g_row
            for (gx = 0; gx < 4; gx = gx + 1) begin : g_col
                localparam int ID = gy*4 + gx;

                torus_router_5x5 #(
                    .CURR_X (gx),
                    .CURR_Y (gy),
                    .FIFO_DEPTH (FIFO_DEPTH)
                ) u_router (
                    .clk      (clk),
                    .rst_n    (rst_n),

                    .in_vld   (rtr_in_vld[ID]),
                    .in_rdy   (rtr_in_rdy[ID]),
                    .in_data  (rtr_in_data[ID]),

                    .out_vld  (rtr_out_vld[ID]),
                    .out_rdy  (rtr_out_rdy[ID]),
                    .out_data (rtr_out_data[ID])
                );
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Hook up LOCAL ports to the top-level injection/ejection buses
    // -------------------------------------------------------------------------
    genvar gi;
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : g_local
            // Injection: testbench -> router LOCAL input
            assign rtr_in_vld [gi][LOCAL] = local_in_vld [gi];
            assign rtr_in_data[gi][LOCAL] = local_in_data[gi];
            assign local_in_rdy[gi]       = rtr_in_rdy [gi][LOCAL];

            // Ejection: router LOCAL output -> testbench
            assign local_out_vld [gi]        = rtr_out_vld [gi][LOCAL];
            assign local_out_data[gi]        = rtr_out_data[gi][LOCAL];
            assign rtr_out_rdy   [gi][LOCAL] = local_out_rdy[gi];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Torus inter-router wiring (with wrap-around)
    // -------------------------------------------------------------------------
    generate
        for (gy = 0; gy < 4; gy = gy + 1) begin : g_link_y
            for (gx = 0; gx < 4; gx = gx + 1) begin : g_link_x
                localparam int ID    = gy*4 + gx;
                localparam int ID_E  = gy*4 + ((gx + 1) % 4);              // east neighbor
                localparam int ID_W  = gy*4 + ((gx + 3) % 4);              // west neighbor
                localparam int ID_N  = ((gy + 1) % 4) * 4 + gx;            // north neighbor
                localparam int ID_S  = ((gy + 3) % 4) * 4 + gx;            // south neighbor

                // EAST output of (x,y) -> WEST input of east-neighbor
                assign rtr_in_vld [ID_E][WEST] = rtr_out_vld [ID][EAST];
                assign rtr_in_data[ID_E][WEST] = rtr_out_data[ID][EAST];
                assign rtr_out_rdy[ID  ][EAST] = rtr_in_rdy [ID_E][WEST];

                // WEST output of (x,y) -> EAST input of west-neighbor
                assign rtr_in_vld [ID_W][EAST] = rtr_out_vld [ID][WEST];
                assign rtr_in_data[ID_W][EAST] = rtr_out_data[ID][WEST];
                assign rtr_out_rdy[ID  ][WEST] = rtr_in_rdy [ID_W][EAST];

                // NORTH output of (x,y) -> SOUTH input of north-neighbor
                assign rtr_in_vld [ID_N][SOUTH] = rtr_out_vld [ID][NORTH];
                assign rtr_in_data[ID_N][SOUTH] = rtr_out_data[ID][NORTH];
                assign rtr_out_rdy[ID  ][NORTH] = rtr_in_rdy [ID_N][SOUTH];

                // SOUTH output of (x,y) -> NORTH input of south-neighbor
                assign rtr_in_vld [ID_S][NORTH] = rtr_out_vld [ID][SOUTH];
                assign rtr_in_data[ID_S][NORTH] = rtr_out_data[ID][SOUTH];
                assign rtr_out_rdy[ID  ][SOUTH] = rtr_in_rdy [ID_S][NORTH];
            end
        end
    endgenerate

endmodule
