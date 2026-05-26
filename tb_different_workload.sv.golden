`timescale 1ns/1ps

// =============================================================================
// tb_router_comparison — single-router traffic / performance testbench
//
//  WHAT THIS TESTS
//   It drives the compiled torus_4x4 (whatever routing is baked into
//   xy_route_logic) with a selectable traffic pattern under random
//   backpressure, then reports throughput, an approximate average latency,
//   and full payload-count correctness.
//
// LATENCY CAVEAT
//   The flit is 8 bits ([dest_x, dest_y, payload]) with no packet ID, so a
//   received packet cannot be uniquely matched to its send event. Latency
//   below is an APPROXIMATION: per destination, each arrival is matched to the
//   oldest still-outstanding send to that destination. Arbitration can reorder
//   packets, so treat the average as indicative, not exact. Throughput
//   (cycles for all packets) and the payload-count check are exact.
// =============================================================================

module tb_noc_workload_comparison;

    // ============================================
    // Parameters
    // ============================================
    localparam int NUM_NODES    = 16;
    localparam int PKTS_PER_SRC = 1000;          // adjust for load (e.g. 200 light, 5000 heavy)
    localparam int TOTAL_PKTS   = NUM_NODES * PKTS_PER_SRC;
    localparam int MAX_CYCLES   = 2000000;

    typedef enum {
        UNIFORM_RANDOM,
        HOTSPOT,            // BP_HOTSPOT_PCT% to node 0, rest random
        BIT_COMPLEMENT,     // 0<->15, 1<->14, ...  
        TORNADO,            // src -> (src+8) mod 16
        MATRIX_TRANSPOSE,   // (x,y) -> (y,x)
        NEIGHBOR_BURST
    } traffic_pattern_t;

    localparam traffic_pattern_t TRAFFIC_PATTERN = BIT_COMPLEMENT;

    localparam int BP_READY_PERCENT = 70;        // 0..100, lower = more backpressure
    localparam int BP_HOTSPOT_PCT   = 10;        // % of HOTSPOT traffic aimed at node 0

    // ============================================
    // Signals
    // ============================================
    logic              clk;
    logic              rst_n;

    logic [15:0]       local_in_vld;
    logic [15:0]       local_in_rdy;
    logic [15:0][7:0]  local_in_data;

    logic [15:0]       local_out_vld;
    logic [15:0]       local_out_rdy;
    logic [15:0][7:0]  local_out_data;

    // Statistics
    int pass_count, fail_count;
    int total_recv_count, total_send_count;
    int sim_cycles;

    // Latency (in clock cycles)
    int max_latency;
    int min_latency;
    longint total_latency;
    int latency_samples;

    // Free-running cycle counter for timestamps (cleared by reset)
    int g_cycle;

    // Per-destination ring buffer of send-cycle timestamps (O(1) match, no
    // O(N^2) scan). Plain 2D array + head/tail so it is portable across
    // simulators (an unpacked array of queues can't be runtime-indexed in
    // some tools). Sized to hold all outstanding sends to one dst.
    localparam int TSQ_DEPTH = TOTAL_PKTS + 1;
    int  send_ts_mem  [0:NUM_NODES-1][0:TSQ_DEPTH-1];
    int  send_ts_head [0:NUM_NODES-1];   // pop position
    int  send_ts_tail [0:NUM_NODES-1];   // push position

    function automatic int tsq_size(input int d);
        tsq_size = send_ts_tail[d] - send_ts_head[d];
    endfunction

    task automatic tsq_push(input int d, input int val);
        send_ts_mem[d][send_ts_tail[d] % TSQ_DEPTH] = val;
        send_ts_tail[d]++;
    endtask

    function automatic int tsq_pop(input int d);
        tsq_pop = send_ts_mem[d][send_ts_head[d] % TSQ_DEPTH];
        send_ts_head[d]++;
    endfunction

    // Correctness counters
    int exp_count      [0:NUM_NODES-1][0:15];
    int recv_count_arr [0:NUM_NODES-1][0:15];

    torus_4x4 dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .local_in_vld   (local_in_vld),
        .local_in_rdy   (local_in_rdy),
        .local_in_data  (local_in_data),
        .local_out_vld  (local_out_vld),
        .local_out_rdy  (local_out_rdy),
        .local_out_data (local_out_data)
    );

    // ============================================
    // Clock
    // ============================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Free-running cycle counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) g_cycle <= 0;
        else        g_cycle <= g_cycle + 1;
    end

    // Global watchdog: a deadlock shows up as a timeout instead of a hang
    initial begin
        #(MAX_CYCLES * 10 + 100000);
        $display(">>> WATCHDOG TIMEOUT (possible deadlock) recv=%0d/%0d t=%0t",
                 total_recv_count, TOTAL_PKTS, $time);
        $finish;
    end

    // VCD
    initial begin
        $dumpfile("router_comparison.vcd");
        $dumpvars(0, dut);
    end

    // Helpers
    function automatic logic [7:0] make_pkt(
        input logic [1:0] dest_x,
        input logic [1:0] dest_y,
        input logic [3:0] payload
    );
        make_pkt = {dest_x, dest_y, payload};
    endfunction

    function automatic int get_destination(input int src_id, input traffic_pattern_t pattern);
        int dst, src_x, src_y, rand_val;
        src_x = src_id % 4;
        src_y = src_id / 4;
        dst   = src_id;

        case (pattern)
            UNIFORM_RANDOM: begin
                dst = $urandom_range(0, 15);
                while (dst == src_id) dst = $urandom_range(0, 15);
            end

            HOTSPOT: begin
                rand_val = $urandom_range(0, 99);
                if (rand_val < BP_HOTSPOT_PCT) dst = 0;
                else                           dst = $urandom_range(0, 15);
                while (dst == src_id) dst = $urandom_range(0, 15);
            end

            BIT_COMPLEMENT: begin
                dst = (~src_id) & 4'hF;          // 0->15, 1->14, ...
                if (dst == src_id) dst = (src_id + 1) % 16;
            end

            TORNADO: begin
                dst = (src_id + 8) % 16;
            end

            MATRIX_TRANSPOSE: begin
                dst = src_x * 4 + src_y;         // (x,y)->(y,x): new id = x*4 + y
                if (dst == src_id) dst = (src_id + 1) % 16;
            end

            NEIGHBOR_BURST: begin
                rand_val = $urandom_range(0, 99);
                if (rand_val < 80) begin
                    // a torus neighbor of src (E/W/N/S with wrap)
                    case ($urandom_range(0, 3))
                        0: dst = src_y * 4 + ((src_x + 1) % 4);   // east
                        1: dst = src_y * 4 + ((src_x + 3) % 4);   // west
                        2: dst = ((src_y + 1) % 4) * 4 + src_x;   // north
                        3: dst = ((src_y + 3) % 4) * 4 + src_x;   // south
                    endcase
                end else begin
                    dst = $urandom_range(0, 15);
                end
                while (dst == src_id) dst = (dst + 1) % 16;
            end

            default: dst = (src_id + 1) % 16;
        endcase

        get_destination = dst;
    endfunction

    function automatic string pattern_name();
        case (TRAFFIC_PATTERN)
            UNIFORM_RANDOM:   pattern_name = "UNIFORM_RANDOM";
            HOTSPOT:          pattern_name = "HOTSPOT (to node 0)";
            BIT_COMPLEMENT:   pattern_name = "BIT_COMPLEMENT";
            TORNADO:          pattern_name = "TORNADO (+8)";
            MATRIX_TRANSPOSE: pattern_name = "MATRIX_TRANSPOSE";
            NEIGHBOR_BURST:   pattern_name = "NEIGHBOR_BURST";
            default:          pattern_name = "UNKNOWN";
        endcase
    endfunction

    // ============================================
    // Sender (one process per source)
    // ============================================
    task automatic send_src(input int src_id, input traffic_pattern_t pattern);
        int         dst_id;
        int         dst_x;
        int         dst_y;
        int         payload;
        logic [7:0] pkt;
        begin
            @(negedge clk);
            for (int p = 0; p < PKTS_PER_SRC; p++) begin
                dst_id  = get_destination(src_id, pattern);
                dst_x   = dst_id % 4;
                dst_y   = dst_id / 4;
                payload = $urandom_range(0, 15);
                pkt     = make_pkt(dst_x[1:0], dst_y[1:0], payload[3:0]);

                exp_count[dst_id][payload]++;

                local_in_vld[src_id]  = 1'b1;
                local_in_data[src_id] = pkt;

                @(posedge clk);
                while (!local_in_rdy[src_id]) @(posedge clk);

                // accepted this cycle: record send time against the destination
                tsq_push(dst_id, g_cycle);
                total_send_count++;

                @(negedge clk);
            end
            local_in_vld[src_id]  = 1'b0;
            local_in_data[src_id] = '0;
        end
    endtask

    // ============================================
    // Main
    // ============================================
    initial begin
        int latency;
        int mismatches;

        pass_count = 0;
        fail_count = 0;

        $display("==========================================");
        $display("ROUTER TRAFFIC TEST");
        $display("Traffic pattern : %s", pattern_name());
        $display("Packets/source  : %0d  (total %0d)", PKTS_PER_SRC, TOTAL_PKTS);
        $display("Backpressure    : %0d%% ready", BP_READY_PERCENT);
        $display("==========================================");

        // reset stats
        total_recv_count = 0;
        total_send_count = 0;
        max_latency      = 0;
        min_latency      = 2147483647;
        total_latency    = 0;
        latency_samples  = 0;
        sim_cycles       = 0;
        for (int d = 0; d < NUM_NODES; d++) begin
            send_ts_head[d] = 0;
            send_ts_tail[d] = 0;
            for (int p = 0; p < 16; p++) begin
                exp_count[d][p]      = 0;
                recv_count_arr[d][p] = 0;
            end
        end

        // reset DUT
        rst_n         = 0;
        local_in_vld  = '0;
        local_in_data = '0;
        local_out_rdy = '1;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        $display("[%0t] Starting traffic...", $time);

        // 16 truly-parallel senders + 1 backpressure driver
        fork
            send_src(0,  TRAFFIC_PATTERN);
            send_src(1,  TRAFFIC_PATTERN);
            send_src(2,  TRAFFIC_PATTERN);
            send_src(3,  TRAFFIC_PATTERN);
            send_src(4,  TRAFFIC_PATTERN);
            send_src(5,  TRAFFIC_PATTERN);
            send_src(6,  TRAFFIC_PATTERN);
            send_src(7,  TRAFFIC_PATTERN);
            send_src(8,  TRAFFIC_PATTERN);
            send_src(9,  TRAFFIC_PATTERN);
            send_src(10, TRAFFIC_PATTERN);
            send_src(11, TRAFFIC_PATTERN);
            send_src(12, TRAFFIC_PATTERN);
            send_src(13, TRAFFIC_PATTERN);
            send_src(14, TRAFFIC_PATTERN);
            send_src(15, TRAFFIC_PATTERN);
            begin : bp_driver
                while (total_recv_count < TOTAL_PKTS) begin
                    @(negedge clk);
                    for (int i = 0; i < NUM_NODES; i++)
                        local_out_rdy[i] = ($urandom_range(0, 99) < BP_READY_PERCENT);
                end
                local_out_rdy = '1;
            end
        join_none

        // monitor / receiver
        while ((total_recv_count < TOTAL_PKTS) && (sim_cycles < MAX_CYCLES)) begin
            @(posedge clk);
            sim_cycles++;

            for (int d = 0; d < NUM_NODES; d++) begin
                if (local_out_vld[d] && local_out_rdy[d]) begin
                    logic [7:0] rx_pkt;
                    logic [1:0] rx_dst_x, rx_dst_y;
                    logic [3:0] rx_payload;
                    int         pkt_dst_id;

                    rx_pkt     = local_out_data[d];
                    rx_dst_x   = rx_pkt[7:6];
                    rx_dst_y   = rx_pkt[5:4];
                    rx_payload = rx_pkt[3:0];
                    pkt_dst_id = rx_dst_y * 4 + rx_dst_x;

                    if (pkt_dst_id != d) begin
                        $display("FAIL[%0t]: wrong dest arrived=%0d pkt_dst=%0d pkt=0x%0h",
                                 $time, d, pkt_dst_id, rx_pkt);
                        fail_count++;
                    end else begin
                        recv_count_arr[d][rx_payload]++;
                        total_recv_count++;

                        // approximate latency: oldest outstanding send to this dst
                        if (tsq_size(d) > 0) begin
                            latency = g_cycle - tsq_pop(d);
                            if (latency < 0) latency = 0;
                            total_latency += latency;
                            latency_samples++;
                            if (latency > max_latency) max_latency = latency;
                            if (latency < min_latency) min_latency = latency;
                        end

                        if ((total_recv_count % (TOTAL_PKTS/10)) == 0)
                            $display("[%0t] Progress: %0d / %0d",
                                     $time, total_recv_count, TOTAL_PKTS);
                    end
                end
            end
        end

        local_out_rdy = '1;

        // ---- results ----
        $display("");
        $display("=== RESULTS ===");
        $display("Cycles taken    : %0d", sim_cycles);
        $display("Packets sent    : %0d / %0d", total_send_count, TOTAL_PKTS);
        $display("Packets received: %0d / %0d", total_recv_count, TOTAL_PKTS);

        if (total_send_count == TOTAL_PKTS) begin
            $display("PASS: all packets sent");    pass_count++;
        end else begin
            $display("FAIL: not all packets sent"); fail_count++;
        end

        if (total_recv_count == TOTAL_PKTS) begin
            $display("PASS: all packets received");    pass_count++;
        end else begin
            $display("FAIL: not all packets received (possible deadlock/timeout)");
            fail_count++;
        end

        if (latency_samples > 0) begin
            $display("");
            $display("Approx latency (cycles, see header caveat):");
            $display("  average : %0d", total_latency / latency_samples);
            $display("  min     : %0d", min_latency);
            $display("  max     : %0d", max_latency);
        end

        mismatches = 0;
        for (int d = 0; d < NUM_NODES; d++)
            for (int p = 0; p < 16; p++)
                if (recv_count_arr[d][p] != exp_count[d][p]) begin
                    if (mismatches < 10)
                        $display("MISMATCH: dst=%0d payload=0x%0h exp=%0d recv=%0d",
                                 d, p, exp_count[d][p], recv_count_arr[d][p]);
                    mismatches++;
                end

        if (mismatches == 0) begin
            $display("PASS: payload counts all match"); pass_count++;
        end else begin
            $display("FAIL: %0d payload mismatches", mismatches); fail_count++;
        end

        $display("------------------------------------------");
        $display("PASS = %0d / 3", pass_count);
        $display("FAIL = %0d", fail_count);
        if (fail_count == 0) $display("FINAL RESULT: PASS");
        else                 $display("FINAL RESULT: FAIL");
        $display("==========================================");

        $finish;
    end

endmodule