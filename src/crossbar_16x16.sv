`timescale 1ns/1ps

// =============================================================================
// crossbar_16x16.sv — fully-connected 16-node VOQ crossbar
//
//   Every node has a dedicated 1-hop path to every other node. There is no
//   multi-hop network, so: no routing, no deadlock machinery, no virtual
//   channels. The only contention is at each destination's ejection arbiter.
//
//   STRUCTURE (per source s):
//     1->16 split on destination bits  ->  16 VOQ FIFOs  (VOQ[s][d])
//   FABRIC (per destination d):
//     gather the 16 heads {VOQ[0][d]..VOQ[15][d]} -> 16->1 masked round-robin
//     -> per-destination OUTPUT FIFO -> local eject.
//
//   "Input buffering after the split, before the merge" == virtual output
//   queueing: a flit blocked for a congested destination never blocks a flit
//   bound for an idle destination (no head-of-line blocking at the source).
//
//   Top module is named torus_4x4 with the SAME port interface as the torus,
//   so the existing testbenches run unmodified. Everything internal is
//   crossbar-named.
//
//   Flit format (unchanged): [dst_x(2), dst_y(2), payload(4)]
//   Node id = dst_y*4 + dst_x.
// =============================================================================


// =============================================================================
// fifo_sync — synchronous FIFO (same proven module as the torus design)
//   ready_out = !full (occupancy-only), valid_out = !empty, registered head.
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


// =============================================================================
// crossbar_merge — N->1 masked round-robin arbiter
//   Same masked round-robin you designed for the torus merge, parameterized
//   to width N (here N=16). Grant = lowest-indexed masked request; mask clears
//   a served port and reloads when exhausted, guaranteeing fairness.
// =============================================================================
module crossbar_merge #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_PORTS  = 16
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
// torus_4x4 — (name kept for testbench compatibility) 16-node VOQ crossbar
// =============================================================================
module torus_4x4 #(
    parameter int VOQ_DEPTH      = 16,
    parameter int OUT_FIFO_DEPTH = 16
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
    localparam int N = 16;

    // ---- VOQ array: voq[s][d] holds flits from source s bound for dest d ----
    logic [7:0] voq_data  [0:N-1][0:N-1];
    logic       voq_vld   [0:N-1][0:N-1];
    logic       voq_rdy   [0:N-1][0:N-1];   // ready_out (space) of each VOQ
    logic       voq_push  [0:N-1][0:N-1];   // push enable into VOQ[s][d]
    logic       voq_pop   [0:N-1][0:N-1];   // ready_in (granted) to VOQ[s][d]

    // ---- INJECTION: per source, 1->16 split on destination id ----
    genvar gs, gd;
    generate
        for (gs = 0; gs < N; gs = gs + 1) begin : g_src
            // destination id from the incoming flit on this source's local port
            logic [3:0] inj_dst;
            assign inj_dst = {local_in_data[gs][5:4], local_in_data[gs][7:6]}; // {dst_y,dst_x}

            // split: assert push only to the chosen destination's VOQ
            always_comb begin
                for (int d = 0; d < N; d++)
                    voq_push[gs][d] = local_in_vld[gs] && (inj_dst == d[3:0]);
            end
            // source is ready iff the chosen destination's VOQ has space
            assign local_in_rdy[gs] = voq_rdy[gs][inj_dst];

            // the 16 VOQ FIFOs for this source
            for (gd = 0; gd < N; gd = gd + 1) begin : g_voq
                fifo_sync #(.DEPTH(VOQ_DEPTH), .DATA_WIDTH(8)) u_voq (
                    .clk(clk), .rst_n(rst_n),
                    .data_in  (local_in_data[gs]),
                    .valid_in (voq_push[gs][gd]),
                    .ready_out(voq_rdy[gs][gd]),
                    .data_out (voq_data[gs][gd]),
                    .valid_out(voq_vld[gs][gd]),
                    .ready_in (voq_pop[gs][gd])
                );
            end
        end
    endgenerate

    // ---- FABRIC + EJECTION: per destination, 16->1 RR merge then output FIFO -
    generate
        for (gd = 0; gd < N; gd = gd + 1) begin : g_dst
            // gather the 16 source VOQ heads bound for this destination
            logic [N-1:0] d_valid;
            logic [N-1:0] d_ready;
            logic [7:0]   d_data [0:N-1];

            for (gs = 0; gs < N; gs = gs + 1) begin : g_gather
                assign d_valid[gs]      = voq_vld [gs][gd];
                assign d_data [gs]      = voq_data[gs][gd];
                assign voq_pop[gs][gd]  = d_ready[gs];
            end

            // 16->1 round-robin arbiter for this destination
            logic       merge_vld;
            logic       merge_rdy;
            logic [7:0] merge_data;

            crossbar_merge #(.DATA_WIDTH(8), .NUM_PORTS(N)) u_merge (
                .clk(clk), .rst_n(rst_n),
                .valid_in (d_valid),
                .ready_in (d_ready),
                .data_in  (d_data),
                .valid_out(merge_vld),
                .ready_out(merge_rdy),
                .data_out (merge_data)
            );

            // per-destination output FIFO -> local eject
            fifo_sync #(.DEPTH(OUT_FIFO_DEPTH), .DATA_WIDTH(8)) u_out_fifo (
                .clk(clk), .rst_n(rst_n),
                .data_in  (merge_data),
                .valid_in (merge_vld),
                .ready_out(merge_rdy),
                .data_out (local_out_data[gd]),
                .valid_out(local_out_vld[gd]),
                .ready_in (local_out_rdy[gd])
            );
        end
    endgenerate

endmodule