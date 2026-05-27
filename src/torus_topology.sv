`timescale 1ns/1ps

// =============================================================================
// 4×4 Torus Network with 16 XY-Routed Routers
// =============================================================================
// Network Layout (x across, y down):
//   (0,0) — (1,0) — (2,0) — (3,0) — (0,0)   [wrap: East from (3,0) to (0,0)]
//     |       |       |       |       |      [wrap: West from (0,0) to (3,0)]
//   (0,1) — (1,1) — (2,1) — (3,1) — (0,1)
//     |       |       |       |       |
//   (0,2) — (1,2) — (2,2) — (3,2) — (0,2)
//     |       |       |       |       |
//   (0,3) — (1,3) — (2,3) — (3,3) — (0,3)
//     |       |       |       |       |
//   (0,0) — (1,0) — (2,0) — (3,0) — (0,0)   [wrap: South from (3,3) to (3,0)]
//                                            [wrap: North from (3,0) to (3,3)]
//
// Manual Instantiation Style — No generate loops, every node wired explicitly
// =============================================================================


`timescale 1ns/1ps

module torus_topology (
    input  logic        clk,
    input  logic        rst_n,

    // =========================================================================
    // LOCAL PORT INTERFACE (for testbench injection/extraction)
    // =========================================================================
    // Input to each router's Local port (from testbench)
    input  logic [15:0] local_in_valid,           // [node]
    input  logic [7:0]  local_in_data  [0:15],    // [node]
    output logic [15:0] local_in_ready,           // [node]

    // Output from each router's Local port (to testbench)
    output logic [15:0] local_out_valid,          // [node]
    output logic [7:0]  local_out_data  [0:15],   // [node]
    input  logic [15:0] local_out_ready           // [node]
);


    // =============================================================================
    // 1. NODE COORDINATES (for each router)
    // =============================================================================
    // Use an always_comb block instead of assign statements for unpacked arrays
    // Index mapping: node_idx(y,x) = y*4 + x
    //   (0,0)=0, (1,0)=1, (2,0)=2, (3,0)=3
    //   (0,1)=4, (1,1)=5, (2,1)=6, (3,1)=7
    //   (0,2)=8, (1,2)=9, (2,2)=10, (3,2)=11
    //   (0,3)=12, (1,3)=13, (2,3)=14, (3,3)=15

    logic [1:0] node_x [0:15];
    logic [1:0] node_y [0:15];

    always_comb begin
        // Row 0 (y=0)
        node_x[0]  = 2'd0; node_y[0]  = 2'd0;  // (0,0)
        node_x[1]  = 2'd1; node_y[1]  = 2'd0;  // (1,0)
        node_x[2]  = 2'd2; node_y[2]  = 2'd0;  // (2,0)
        node_x[3]  = 2'd3; node_y[3]  = 2'd0;  // (3,0)
        
        // Row 1 (y=1)
        node_x[4]  = 2'd0; node_y[4]  = 2'd1;  // (0,1)
        node_x[5]  = 2'd1; node_y[5]  = 2'd1;  // (1,1)
        node_x[6]  = 2'd2; node_y[6]  = 2'd1;  // (2,1)
        node_x[7]  = 2'd3; node_y[7]  = 2'd1;  // (3,1)
        
        // Row 2 (y=2)
        node_x[8]  = 2'd0; node_y[8]  = 2'd2;  // (0,2)
        node_x[9]  = 2'd1; node_y[9]  = 2'd2;  // (1,2)
        node_x[10] = 2'd2; node_y[10] = 2'd2;  // (2,2)
        node_x[11] = 2'd3; node_y[11] = 2'd2;  // (3,2)
        
        // Row 3 (y=3)
        node_x[12] = 2'd0; node_y[12] = 2'd3;  // (0,3)
        node_x[13] = 2'd1; node_y[13] = 2'd3;  // (1,3)
        node_x[14] = 2'd2; node_y[14] = 2'd3;  // (2,3)
        node_x[15] = 2'd3; node_y[15] = 2'd3;  // (3,3)
    end

    // =========================================================================
    // 2. NETWORK INTERCONNECT SIGNALS
    // =========================================================================
    // Router ports: N=0, S=1, E=2, W=3, L=4
    // Arrays: [node_index][port]
    
    logic [4:0] in_valid  [0:15];
    logic [4:0] in_ready  [0:15];
    logic [4:0] out_valid [0:15];
    logic [4:0] out_ready [0:15];
    logic [7:0] in_data   [0:15][0:4];
    logic [7:0] out_data  [0:15][0:4];

    // =========================================================================
    // 3. ROUTER INSTANTIATIONS (16 nodes)
    // =========================================================================

    // Node 0: (0,0)
    router_simple u_router_0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[0]),
        .my_y      (node_y[0]),
        .in_valid  (in_valid[0]),
        .in_ready  (in_ready[0]),
        .in_data_0 (in_data[0][0]),
        .in_data_1 (in_data[0][1]),
        .in_data_2 (in_data[0][2]),
        .in_data_3 (in_data[0][3]),
        .in_data_4 (in_data[0][4]),
        .out_valid (out_valid[0]),
        .out_ready (out_ready[0]),
        .out_data_0(out_data[0][0]),
        .out_data_1(out_data[0][1]),
        .out_data_2(out_data[0][2]),
        .out_data_3(out_data[0][3]),
        .out_data_4(out_data[0][4])
    );

    // Node 1: (1,0)
    router_simple u_router_1 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[1]),
        .my_y      (node_y[1]),
        .in_valid  (in_valid[1]),
        .in_ready  (in_ready[1]),
        .in_data_0 (in_data[1][0]),
        .in_data_1 (in_data[1][1]),
        .in_data_2 (in_data[1][2]),
        .in_data_3 (in_data[1][3]),
        .in_data_4 (in_data[1][4]),
        .out_valid (out_valid[1]),
        .out_ready (out_ready[1]),
        .out_data_0(out_data[1][0]),
        .out_data_1(out_data[1][1]),
        .out_data_2(out_data[1][2]),
        .out_data_3(out_data[1][3]),
        .out_data_4(out_data[1][4])
    );

    // Node 2: (2,0)
    router_simple u_router_2 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[2]),
        .my_y      (node_y[2]),
        .in_valid  (in_valid[2]),
        .in_ready  (in_ready[2]),
        .in_data_0 (in_data[2][0]),
        .in_data_1 (in_data[2][1]),
        .in_data_2 (in_data[2][2]),
        .in_data_3 (in_data[2][3]),
        .in_data_4 (in_data[2][4]),
        .out_valid (out_valid[2]),
        .out_ready (out_ready[2]),
        .out_data_0(out_data[2][0]),
        .out_data_1(out_data[2][1]),
        .out_data_2(out_data[2][2]),
        .out_data_3(out_data[2][3]),
        .out_data_4(out_data[2][4])
    );

    // Node 3: (3,0)
    router_simple u_router_3 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[3]),
        .my_y      (node_y[3]),
        .in_valid  (in_valid[3]),
        .in_ready  (in_ready[3]),
        .in_data_0 (in_data[3][0]),
        .in_data_1 (in_data[3][1]),
        .in_data_2 (in_data[3][2]),
        .in_data_3 (in_data[3][3]),
        .in_data_4 (in_data[3][4]),
        .out_valid (out_valid[3]),
        .out_ready (out_ready[3]),
        .out_data_0(out_data[3][0]),
        .out_data_1(out_data[3][1]),
        .out_data_2(out_data[3][2]),
        .out_data_3(out_data[3][3]),
        .out_data_4(out_data[3][4])
    );

    // Node 4: (0,1)
    router_simple u_router_4 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[4]),
        .my_y      (node_y[4]),
        .in_valid  (in_valid[4]),
        .in_ready  (in_ready[4]),
        .in_data_0 (in_data[4][0]),
        .in_data_1 (in_data[4][1]),
        .in_data_2 (in_data[4][2]),
        .in_data_3 (in_data[4][3]),
        .in_data_4 (in_data[4][4]),
        .out_valid (out_valid[4]),
        .out_ready (out_ready[4]),
        .out_data_0(out_data[4][0]),
        .out_data_1(out_data[4][1]),
        .out_data_2(out_data[4][2]),
        .out_data_3(out_data[4][3]),
        .out_data_4(out_data[4][4])
    );

    // Node 5: (1,1)
    router_simple u_router_5 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[5]),
        .my_y      (node_y[5]),
        .in_valid  (in_valid[5]),
        .in_ready  (in_ready[5]),
        .in_data_0 (in_data[5][0]),
        .in_data_1 (in_data[5][1]),
        .in_data_2 (in_data[5][2]),
        .in_data_3 (in_data[5][3]),
        .in_data_4 (in_data[5][4]),
        .out_valid (out_valid[5]),
        .out_ready (out_ready[5]),
        .out_data_0(out_data[5][0]),
        .out_data_1(out_data[5][1]),
        .out_data_2(out_data[5][2]),
        .out_data_3(out_data[5][3]),
        .out_data_4(out_data[5][4])
    );

    // Node 6: (2,1)
    router_simple u_router_6 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[6]),
        .my_y      (node_y[6]),
        .in_valid  (in_valid[6]),
        .in_ready  (in_ready[6]),
        .in_data_0 (in_data[6][0]),
        .in_data_1 (in_data[6][1]),
        .in_data_2 (in_data[6][2]),
        .in_data_3 (in_data[6][3]),
        .in_data_4 (in_data[6][4]),
        .out_valid (out_valid[6]),
        .out_ready (out_ready[6]),
        .out_data_0(out_data[6][0]),
        .out_data_1(out_data[6][1]),
        .out_data_2(out_data[6][2]),
        .out_data_3(out_data[6][3]),
        .out_data_4(out_data[6][4])
    );

    // Node 7: (3,1)
    router_simple u_router_7 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[7]),
        .my_y      (node_y[7]),
        .in_valid  (in_valid[7]),
        .in_ready  (in_ready[7]),
        .in_data_0 (in_data[7][0]),
        .in_data_1 (in_data[7][1]),
        .in_data_2 (in_data[7][2]),
        .in_data_3 (in_data[7][3]),
        .in_data_4 (in_data[7][4]),
        .out_valid (out_valid[7]),
        .out_ready (out_ready[7]),
        .out_data_0(out_data[7][0]),
        .out_data_1(out_data[7][1]),
        .out_data_2(out_data[7][2]),
        .out_data_3(out_data[7][3]),
        .out_data_4(out_data[7][4])
    );

    // Node 8: (0,2)
    router_simple u_router_8 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[8]),
        .my_y      (node_y[8]),
        .in_valid  (in_valid[8]),
        .in_ready  (in_ready[8]),
        .in_data_0 (in_data[8][0]),
        .in_data_1 (in_data[8][1]),
        .in_data_2 (in_data[8][2]),
        .in_data_3 (in_data[8][3]),
        .in_data_4 (in_data[8][4]),
        .out_valid (out_valid[8]),
        .out_ready (out_ready[8]),
        .out_data_0(out_data[8][0]),
        .out_data_1(out_data[8][1]),
        .out_data_2(out_data[8][2]),
        .out_data_3(out_data[8][3]),
        .out_data_4(out_data[8][4])
    );

    // Node 9: (1,2)
    router_simple u_router_9 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[9]),
        .my_y      (node_y[9]),
        .in_valid  (in_valid[9]),
        .in_ready  (in_ready[9]),
        .in_data_0 (in_data[9][0]),
        .in_data_1 (in_data[9][1]),
        .in_data_2 (in_data[9][2]),
        .in_data_3 (in_data[9][3]),
        .in_data_4 (in_data[9][4]),
        .out_valid (out_valid[9]),
        .out_ready (out_ready[9]),
        .out_data_0(out_data[9][0]),
        .out_data_1(out_data[9][1]),
        .out_data_2(out_data[9][2]),
        .out_data_3(out_data[9][3]),
        .out_data_4(out_data[9][4])
    );

    // Node 10: (2,2)
    router_simple u_router_10 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[10]),
        .my_y      (node_y[10]),
        .in_valid  (in_valid[10]),
        .in_ready  (in_ready[10]),
        .in_data_0 (in_data[10][0]),
        .in_data_1 (in_data[10][1]),
        .in_data_2 (in_data[10][2]),
        .in_data_3 (in_data[10][3]),
        .in_data_4 (in_data[10][4]),
        .out_valid (out_valid[10]),
        .out_ready (out_ready[10]),
        .out_data_0(out_data[10][0]),
        .out_data_1(out_data[10][1]),
        .out_data_2(out_data[10][2]),
        .out_data_3(out_data[10][3]),
        .out_data_4(out_data[10][4])
    );

    // Node 11: (3,2)
    router_simple u_router_11 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[11]),
        .my_y      (node_y[11]),
        .in_valid  (in_valid[11]),
        .in_ready  (in_ready[11]),
        .in_data_0 (in_data[11][0]),
        .in_data_1 (in_data[11][1]),
        .in_data_2 (in_data[11][2]),
        .in_data_3 (in_data[11][3]),
        .in_data_4 (in_data[11][4]),
        .out_valid (out_valid[11]),
        .out_ready (out_ready[11]),
        .out_data_0(out_data[11][0]),
        .out_data_1(out_data[11][1]),
        .out_data_2(out_data[11][2]),
        .out_data_3(out_data[11][3]),
        .out_data_4(out_data[11][4])
    );

    // Node 12: (0,3)
    router_simple u_router_12 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[12]),
        .my_y      (node_y[12]),
        .in_valid  (in_valid[12]),
        .in_ready  (in_ready[12]),
        .in_data_0 (in_data[12][0]),
        .in_data_1 (in_data[12][1]),
        .in_data_2 (in_data[12][2]),
        .in_data_3 (in_data[12][3]),
        .in_data_4 (in_data[12][4]),
        .out_valid (out_valid[12]),
        .out_ready (out_ready[12]),
        .out_data_0(out_data[12][0]),
        .out_data_1(out_data[12][1]),
        .out_data_2(out_data[12][2]),
        .out_data_3(out_data[12][3]),
        .out_data_4(out_data[12][4])
    );

    // Node 13: (1,3)
    router_simple u_router_13 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[13]),
        .my_y      (node_y[13]),
        .in_valid  (in_valid[13]),
        .in_ready  (in_ready[13]),
        .in_data_0 (in_data[13][0]),
        .in_data_1 (in_data[13][1]),
        .in_data_2 (in_data[13][2]),
        .in_data_3 (in_data[13][3]),
        .in_data_4 (in_data[13][4]),
        .out_valid (out_valid[13]),
        .out_ready (out_ready[13]),
        .out_data_0(out_data[13][0]),
        .out_data_1(out_data[13][1]),
        .out_data_2(out_data[13][2]),
        .out_data_3(out_data[13][3]),
        .out_data_4(out_data[13][4])
    );

    // Node 14: (2,3)
    router_simple u_router_14 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[14]),
        .my_y      (node_y[14]),
        .in_valid  (in_valid[14]),
        .in_ready  (in_ready[14]),
        .in_data_0 (in_data[14][0]),
        .in_data_1 (in_data[14][1]),
        .in_data_2 (in_data[14][2]),
        .in_data_3 (in_data[14][3]),
        .in_data_4 (in_data[14][4]),
        .out_valid (out_valid[14]),
        .out_ready (out_ready[14]),
        .out_data_0(out_data[14][0]),
        .out_data_1(out_data[14][1]),
        .out_data_2(out_data[14][2]),
        .out_data_3(out_data[14][3]),
        .out_data_4(out_data[14][4])
    );

    // Node 15: (3,3)
    router_simple u_router_15 (
        .clk       (clk),
        .rst_n     (rst_n),
        .my_x      (node_x[15]),
        .my_y      (node_y[15]),
        .in_valid  (in_valid[15]),
        .in_ready  (in_ready[15]),
        .in_data_0 (in_data[15][0]),
        .in_data_1 (in_data[15][1]),
        .in_data_2 (in_data[15][2]),
        .in_data_3 (in_data[15][3]),
        .in_data_4 (in_data[15][4]),
        .out_valid (out_valid[15]),
        .out_ready (out_ready[15]),
        .out_data_0(out_data[15][0]),
        .out_data_1(out_data[15][1]),
        .out_data_2(out_data[15][2]),
        .out_data_3(out_data[15][3]),
        .out_data_4(out_data[15][4])
    );

    // =========================================================================
    // 4. TORUS WIRING (All 16 nodes fully connected manually)
    // =========================================================================
    // Port mapping: N=0, S=1, E=2, W=3, L=4
    //
    // For each edge:
    //   in_valid[TO_NODE][TO_PORT] = out_valid[FROM_NODE][FROM_PORT]
    //   out_ready[FROM_NODE][FROM_PORT] = in_ready[TO_NODE][TO_PORT]
    //   in_data[TO_NODE][TO_PORT] = out_data[FROM_NODE][FROM_PORT]

    // =========================================================================
    // ROW 0 CONNECTIONS (y=0)
    // =========================================================================
    
    // Node 0 (0,0) North ← Node 12 (0,3) South (wrap)
    assign in_valid[0][0]   = out_valid[12][1];
    assign out_ready[12][1] = in_ready[0][0];
    assign in_data[0][0]    = out_data[12][1];
    
    // Node 0 (0,0) South → Node 4 (0,1) North
    assign in_valid[4][0]   = out_valid[0][1];
    assign out_ready[0][1]  = in_ready[4][0];
    assign in_data[4][0]    = out_data[0][1];
    
    // Node 0 (0,0) East → Node 1 (1,0) West
    assign in_valid[1][3]   = out_valid[0][2];
    assign out_ready[0][2]  = in_ready[1][3];
    assign in_data[1][3]    = out_data[0][2];
    
    // Node 0 (0,0) West ← Node 3 (3,0) East (wrap)
    assign in_valid[0][3]   = out_valid[3][2];
    assign out_ready[3][2]  = in_ready[0][3];
    assign in_data[0][3]    = out_data[3][2];

    // Node 1 (1,0) North ← Node 13 (1,3) South (wrap)
    assign in_valid[1][0]   = out_valid[13][1];
    assign out_ready[13][1] = in_ready[1][0];
    assign in_data[1][0]    = out_data[13][1];
    
    // Node 1 (1,0) South → Node 5 (1,1) North
    assign in_valid[5][0]   = out_valid[1][1];
    assign out_ready[1][1]  = in_ready[5][0];
    assign in_data[5][0]    = out_data[1][1];
    
    // Node 1 (1,0) East → Node 2 (2,0) West
    assign in_valid[2][3]   = out_valid[1][2];
    assign out_ready[1][2]  = in_ready[2][3];
    assign in_data[2][3]    = out_data[1][2];
    
    // Node 1 (1,0) West ← Node 0 (0,0) East
    assign in_valid[1][3]   = out_valid[0][2];
    assign out_ready[0][2]  = in_ready[1][3];
    assign in_data[1][3]    = out_data[0][2];

    // Node 2 (2,0) North ← Node 14 (2,3) South (wrap)
    assign in_valid[2][0]   = out_valid[14][1];
    assign out_ready[14][1] = in_ready[2][0];
    assign in_data[2][0]    = out_data[14][1];
    
    // Node 2 (2,0) South → Node 6 (2,1) North
    assign in_valid[6][0]   = out_valid[2][1];
    assign out_ready[2][1]  = in_ready[6][0];
    assign in_data[6][0]    = out_data[2][1];
    
    // Node 2 (2,0) East → Node 3 (3,0) West
    assign in_valid[3][3]   = out_valid[2][2];
    assign out_ready[2][2]  = in_ready[3][3];
    assign in_data[3][3]    = out_data[2][2];
    
    // Node 2 (2,0) West ← Node 1 (1,0) East
    assign in_valid[2][3]   = out_valid[1][2];
    assign out_ready[1][2]  = in_ready[2][3];
    assign in_data[2][3]    = out_data[1][2];

    // Node 3 (3,0) North ← Node 15 (3,3) South (wrap)
    assign in_valid[3][0]   = out_valid[15][1];
    assign out_ready[15][1] = in_ready[3][0];
    assign in_data[3][0]    = out_data[15][1];
    
    // Node 3 (3,0) South → Node 7 (3,1) North
    assign in_valid[7][0]   = out_valid[3][1];
    assign out_ready[3][1]  = in_ready[7][0];
    assign in_data[7][0]    = out_data[3][1];
    
    // Node 3 (3,0) East → Node 0 (0,0) West (wrap)
    assign in_valid[0][3]   = out_valid[3][2];
    assign out_ready[3][2]  = in_ready[0][3];
    assign in_data[0][3]    = out_data[3][2];
    
    // Node 3 (3,0) West ← Node 2 (2,0) East
    assign in_valid[3][3]   = out_valid[2][2];
    assign out_ready[2][2]  = in_ready[3][3];
    assign in_data[3][3]    = out_data[2][2];

    // =========================================================================
    // ROW 1 CONNECTIONS (y=1)
    // =========================================================================
    
    // Node 4 (0,1) North ← Node 0 (0,0) South
    assign in_valid[4][0]   = out_valid[0][1];
    assign out_ready[0][1]  = in_ready[4][0];
    assign in_data[4][0]    = out_data[0][1];
    
    // Node 4 (0,1) South → Node 8 (0,2) North
    assign in_valid[8][0]   = out_valid[4][1];
    assign out_ready[4][1]  = in_ready[8][0];
    assign in_data[8][0]    = out_data[4][1];
    
    // Node 4 (0,1) East → Node 5 (1,1) West
    assign in_valid[5][3]   = out_valid[4][2];
    assign out_ready[4][2]  = in_ready[5][3];
    assign in_data[5][3]    = out_data[4][2];
    
    // Node 4 (0,1) West ← Node 7 (3,1) East (wrap)
    assign in_valid[4][3]   = out_valid[7][2];
    assign out_ready[7][2]  = in_ready[4][3];
    assign in_data[4][3]    = out_data[7][2];

    // Node 5 (1,1) North ← Node 1 (1,0) South
    assign in_valid[5][0]   = out_valid[1][1];
    assign out_ready[1][1]  = in_ready[5][0];
    assign in_data[5][0]    = out_data[1][1];
    
    // Node 5 (1,1) South → Node 9 (1,2) North
    assign in_valid[9][0]   = out_valid[5][1];
    assign out_ready[5][1]  = in_ready[9][0];
    assign in_data[9][0]    = out_data[5][1];
    
    // Node 5 (1,1) East → Node 6 (2,1) West
    assign in_valid[6][3]   = out_valid[5][2];
    assign out_ready[5][2]  = in_ready[6][3];
    assign in_data[6][3]    = out_data[5][2];
    
    // Node 5 (1,1) West ← Node 4 (0,1) East
    assign in_valid[5][3]   = out_valid[4][2];
    assign out_ready[4][2]  = in_ready[5][3];
    assign in_data[5][3]    = out_data[4][2];

    // Node 6 (2,1) North ← Node 2 (2,0) South
    assign in_valid[6][0]   = out_valid[2][1];
    assign out_ready[2][1]  = in_ready[6][0];
    assign in_data[6][0]    = out_data[2][1];
    
    // Node 6 (2,1) South → Node 10 (2,2) North
    assign in_valid[10][0]  = out_valid[6][1];
    assign out_ready[6][1]  = in_ready[10][0];
    assign in_data[10][0]   = out_data[6][1];
    
    // Node 6 (2,1) East → Node 7 (3,1) West
    assign in_valid[7][3]   = out_valid[6][2];
    assign out_ready[6][2]  = in_ready[7][3];
    assign in_data[7][3]    = out_data[6][2];
    
    // Node 6 (2,1) West ← Node 5 (1,1) East
    assign in_valid[6][3]   = out_valid[5][2];
    assign out_ready[5][2]  = in_ready[6][3];
    assign in_data[6][3]    = out_data[5][2];

    // Node 7 (3,1) North ← Node 3 (3,0) South
    assign in_valid[7][0]   = out_valid[3][1];
    assign out_ready[3][1]  = in_ready[7][0];
    assign in_data[7][0]    = out_data[3][1];
    
    // Node 7 (3,1) South → Node 11 (3,2) North
    assign in_valid[11][0]  = out_valid[7][1];
    assign out_ready[7][1]  = in_ready[11][0];
    assign in_data[11][0]   = out_data[7][1];
    
    // Node 7 (3,1) East → Node 4 (0,1) West (wrap)
    assign in_valid[4][3]   = out_valid[7][2];
    assign out_ready[7][2]  = in_ready[4][3];
    assign in_data[4][3]    = out_data[7][2];
    
    // Node 7 (3,1) West ← Node 6 (2,1) East
    assign in_valid[7][3]   = out_valid[6][2];
    assign out_ready[6][2]  = in_ready[7][3];
    assign in_data[7][3]    = out_data[6][2];

    // =========================================================================
    // ROW 2 CONNECTIONS (y=2)
    // =========================================================================
    
    // Node 8 (0,2) North ← Node 4 (0,1) South
    assign in_valid[8][0]   = out_valid[4][1];
    assign out_ready[4][1]  = in_ready[8][0];
    assign in_data[8][0]    = out_data[4][1];
    
    // Node 8 (0,2) South → Node 12 (0,3) North
    assign in_valid[12][0]  = out_valid[8][1];
    assign out_ready[8][1]  = in_ready[12][0];
    assign in_data[12][0]   = out_data[8][1];
    
    // Node 8 (0,2) East → Node 9 (1,2) West
    assign in_valid[9][3]   = out_valid[8][2];
    assign out_ready[8][2]  = in_ready[9][3];
    assign in_data[9][3]    = out_data[8][2];
    
    // Node 8 (0,2) West ← Node 11 (3,2) East (wrap)
    assign in_valid[8][3]   = out_valid[11][2];
    assign out_ready[11][2] = in_ready[8][3];
    assign in_data[8][3]    = out_data[11][2];

    // Node 9 (1,2) North ← Node 5 (1,1) South
    assign in_valid[9][0]   = out_valid[5][1];
    assign out_ready[5][1]  = in_ready[9][0];
    assign in_data[9][0]    = out_data[5][1];
    
    // Node 9 (1,2) South → Node 13 (1,3) North
    assign in_valid[13][0]  = out_valid[9][1];
    assign out_ready[9][1]  = in_ready[13][0];
    assign in_data[13][0]   = out_data[9][1];
    
    // Node 9 (1,2) East → Node 10 (2,2) West
    assign in_valid[10][3]  = out_valid[9][2];
    assign out_ready[9][2]  = in_ready[10][3];
    assign in_data[10][3]   = out_data[9][2];
    
    // Node 9 (1,2) West ← Node 8 (0,2) East
    assign in_valid[9][3]   = out_valid[8][2];
    assign out_ready[8][2]  = in_ready[9][3];
    assign in_data[9][3]    = out_data[8][2];

    // Node 10 (2,2) North ← Node 6 (2,1) South
    assign in_valid[10][0]  = out_valid[6][1];
    assign out_ready[6][1]  = in_ready[10][0];
    assign in_data[10][0]   = out_data[6][1];
    
    // Node 10 (2,2) South → Node 14 (2,3) North
    assign in_valid[14][0]  = out_valid[10][1];
    assign out_ready[10][1] = in_ready[14][0];
    assign in_data[14][0]   = out_data[10][1];
    
    // Node 10 (2,2) East → Node 11 (3,2) West
    assign in_valid[11][3]  = out_valid[10][2];
    assign out_ready[10][2] = in_ready[11][3];
    assign in_data[11][3]   = out_data[10][2];
    
    // Node 10 (2,2) West ← Node 9 (1,2) East
    assign in_valid[10][3]  = out_valid[9][2];
    assign out_ready[9][2]  = in_ready[10][3];
    assign in_data[10][3]   = out_data[9][2];

    // Node 11 (3,2) North ← Node 7 (3,1) South
    assign in_valid[11][0]  = out_valid[7][1];
    assign out_ready[7][1]  = in_ready[11][0];
    assign in_data[11][0]   = out_data[7][1];
    
    // Node 11 (3,2) South → Node 15 (3,3) North
    assign in_valid[15][0]  = out_valid[11][1];
    assign out_ready[11][1] = in_ready[15][0];
    assign in_data[15][0]   = out_data[11][1];
    
    // Node 11 (3,2) East → Node 8 (0,2) West (wrap)
    assign in_valid[8][3]   = out_valid[11][2];
    assign out_ready[11][2] = in_ready[8][3];
    assign in_data[8][3]    = out_data[11][2];
    
    // Node 11 (3,2) West ← Node 10 (2,2) East
    assign in_valid[11][3]  = out_valid[10][2];
    assign out_ready[10][2] = in_ready[11][3];
    assign in_data[11][3]   = out_data[10][2];

    // =========================================================================
    // ROW 3 CONNECTIONS (y=3)
    // =========================================================================
    
    // Node 12 (0,3) North ← Node 8 (0,2) South
    assign in_valid[12][0]  = out_valid[8][1];
    assign out_ready[8][1]  = in_ready[12][0];
    assign in_data[12][0]   = out_data[8][1];
    
    // Node 12 (0,3) South → Node 0 (0,0) North (wrap)
    assign in_valid[0][0]   = out_valid[12][1];
    assign out_ready[12][1] = in_ready[0][0];
    assign in_data[0][0]    = out_data[12][1];
    
    // Node 12 (0,3) East → Node 13 (1,3) West
    assign in_valid[13][3]  = out_valid[12][2];
    assign out_ready[12][2] = in_ready[13][3];
    assign in_data[13][3]   = out_data[12][2];
    
    // Node 12 (0,3) West ← Node 15 (3,3) East (wrap)
    assign in_valid[12][3]  = out_valid[15][2];
    assign out_ready[15][2] = in_ready[12][3];
    assign in_data[12][3]   = out_data[15][2];

    // Node 13 (1,3) North ← Node 9 (1,2) South
    assign in_valid[13][0]  = out_valid[9][1];
    assign out_ready[9][1]  = in_ready[13][0];
    assign in_data[13][0]   = out_data[9][1];
    
    // Node 13 (1,3) South → Node 1 (1,0) North (wrap)
    assign in_valid[1][0]   = out_valid[13][1];
    assign out_ready[13][1] = in_ready[1][0];
    assign in_data[1][0]    = out_data[13][1];
    
    // Node 13 (1,3) East → Node 14 (2,3) West
    assign in_valid[14][3]  = out_valid[13][2];
    assign out_ready[13][2] = in_ready[14][3];
    assign in_data[14][3]   = out_data[13][2];
    
    // Node 13 (1,3) West ← Node 12 (0,3) East
    assign in_valid[13][3]  = out_valid[12][2];
    assign out_ready[12][2] = in_ready[13][3];
    assign in_data[13][3]   = out_data[12][2];

    // Node 14 (2,3) North ← Node 10 (2,2) South
    assign in_valid[14][0]  = out_valid[10][1];
    assign out_ready[10][1] = in_ready[14][0];
    assign in_data[14][0]   = out_data[10][1];
    
    // Node 14 (2,3) South → Node 2 (2,0) North (wrap)
    assign in_valid[2][0]   = out_valid[14][1];
    assign out_ready[14][1] = in_ready[2][0];
    assign in_data[2][0]    = out_data[14][1];
    
    // Node 14 (2,3) East → Node 15 (3,3) West
    assign in_valid[15][3]  = out_valid[14][2];
    assign out_ready[14][2] = in_ready[15][3];
    assign in_data[15][3]   = out_data[14][2];
    
    // Node 14 (2,3) West ← Node 13 (1,3) East
    assign in_valid[14][3]  = out_valid[13][2];
    assign out_ready[13][2] = in_ready[14][3];
    assign in_data[14][3]   = out_data[13][2];

    // Node 15 (3,3) North ← Node 11 (3,2) South
    assign in_valid[15][0]  = out_valid[11][1];
    assign out_ready[11][1] = in_ready[15][0];
    assign in_data[15][0]   = out_data[11][1];
    
    // Node 15 (3,3) South → Node 3 (3,0) North (wrap)
    assign in_valid[3][0]   = out_valid[15][1];
    assign out_ready[15][1] = in_ready[3][0];
    assign in_data[3][0]    = out_data[15][1];
    
    // Node 15 (3,3) East → Node 12 (0,3) West (wrap)
    assign in_valid[12][3]  = out_valid[15][2];
    assign out_ready[15][2] = in_ready[12][3];
    assign in_data[12][3]   = out_data[15][2];
    
    // Node 15 (3,3) West ← Node 14 (2,3) East
    assign in_valid[15][3]  = out_valid[14][2];
    assign out_ready[14][2] = in_ready[15][3];
    assign in_data[15][3]   = out_data[14][2];

    // =========================================================================
    // 5. LOCAL PORT CONNECTIONS (Testbench Interface)
    // =========================================================================
    // Connect each router's Local port (index 4) to the module ports
    
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : gen_local_connections
            // Local input (testbench → router)
            assign in_valid[i][4] = local_in_valid[i];
            assign in_data[i][4]  = local_in_data[i];
            assign local_in_ready[i] = in_ready[i][4];
            
            // Local output (router → testbench)
            assign local_out_valid[i] = out_valid[i][4];
            assign local_out_data[i]  = out_data[i][4];
            assign out_ready[i][4] = local_out_ready[i];
        end
    endgenerate

endmodule