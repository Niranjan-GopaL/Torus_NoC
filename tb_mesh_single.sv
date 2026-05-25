`timescale 1ns/1ps

module tb_torus_4x4_congestion_b2b;

    localparam int DST_ID      = 15; // (3,3)
    localparam int NUM_PKTS_PS = 4;
    localparam int EXP_PKTS    = 15 * NUM_PKTS_PS;

    logic              clk;
    logic              rst_n;

    logic [15:0]       local_in_vld;
    logic [15:0]       local_in_rdy;
    logic [15:0][7:0]  local_in_data;

    logic [15:0]       local_out_vld;
    logic [15:0]       local_out_rdy;
    logic [15:0][7:0]  local_out_data;

    int pass_count;
    int fail_count;
    int recv_count;

    int exp_payload_count  [0:15];
    int recv_payload_count [0:15];

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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("torus_4x4_congestion_b2b.vcd");
        $dumpvars(0, tb_torus_4x4_congestion_b2b);
    end

    function automatic logic [7:0] make_pkt(
        input logic [1:0] dest_x,
        input logic [1:0] dest_y,
        input logic [3:0] payload
    );
        make_pkt = {dest_x, dest_y, payload};
    endfunction

    // Safer B2B sender:
    // Drives vld/data at negedge, so data is stable before posedge.
    // Advances to next packet only after a posedge where ready is high.
    task automatic send_b2b_from_src(
        input int src_id
    );
        logic [7:0] pkt;

        begin
            @(negedge clk);

            for (int p = 0; p < NUM_PKTS_PS; p++) begin

                pkt = make_pkt(2'd3, 2'd3, src_id[3:0] ^ p[3:0]);

                local_in_vld[src_id]  = 1'b1;
                local_in_data[src_id] = pkt;

                @(posedge clk);

                while (!local_in_rdy[src_id]) begin
                    @(posedge clk);
                end

                @(negedge clk);
            end

            local_in_vld[src_id]  = 1'b0;
            local_in_data[src_id] = '0;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        recv_count = 0;

        for (int i = 0; i < 16; i++) begin
            exp_payload_count[i]  = 0;
            recv_payload_count[i] = 0;
        end

        for (int s = 0; s < 15; s++) begin
            for (int p = 0; p < NUM_PKTS_PS; p++) begin
                exp_payload_count[s[3:0] ^ p[3:0]]++;
            end
        end

        rst_n = 0;

        local_in_vld  = '0;
        local_in_data = '0;
        local_out_rdy = '1;

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        $display("Starting B2B single-destination congestion test...");

        fork
            send_b2b_from_src(0);
            send_b2b_from_src(1);
            send_b2b_from_src(2);
            send_b2b_from_src(3);
            send_b2b_from_src(4);
            send_b2b_from_src(5);
            send_b2b_from_src(6);
            send_b2b_from_src(7);
            send_b2b_from_src(8);
            send_b2b_from_src(9);
            send_b2b_from_src(10);
            send_b2b_from_src(11);
            send_b2b_from_src(12);
            send_b2b_from_src(13);
            send_b2b_from_src(14);
        join_none

        for (int t = 0; (t < 20000) && (recv_count < EXP_PKTS); t++) begin
            @(posedge clk);

            // No packet should appear at any wrong local destination
            for (int d = 0; d < 15; d++) begin
                if (local_out_vld[d] && local_out_rdy[d]) begin
                    $display("FAIL: wrong destination dst=%0d pkt=0x%0h time=%0t",
                             d, local_out_data[d], $time);
                    fail_count++;
                end
            end

            // Expected destination = node 15
            if (local_out_vld[DST_ID] && local_out_rdy[DST_ID]) begin
                logic [3:0] payload;

                payload = local_out_data[DST_ID][3:0];

                if (local_out_data[DST_ID][7:4] !== 4'b1111) begin
                    $display("FAIL: wrong dest bits at dst15 pkt=0x%0h time=%0t",
                             local_out_data[DST_ID], $time);
                    fail_count++;
                end else begin
                    recv_payload_count[payload]++;
                    recv_count++;

                    $display("[%0t] RX dst15 pkt=0x%0h payload=0x%0h total=%0d",
                             $time, local_out_data[DST_ID], payload, recv_count);
                end
            end
        end

        if (recv_count != EXP_PKTS) begin
            $display("FAIL: expected %0d packets, received %0d",
                     EXP_PKTS, recv_count);
            fail_count++;
        end else begin
            $display("PASS: received all %0d packets", EXP_PKTS);
            pass_count++;
        end

        for (int i = 0; i < 16; i++) begin
            if (recv_payload_count[i] != exp_payload_count[i]) begin
                $display("FAIL: payload=0x%0h expected=%0d received=%0d",
                         i, exp_payload_count[i], recv_payload_count[i]);
                fail_count++;
            end
        end

        // Extra packet check after expected packets received
        repeat (50) begin
            @(posedge clk);

            if (local_out_vld[DST_ID] && local_out_rdy[DST_ID]) begin
                $display("FAIL: extra packet after expected packets pkt=0x%0h time=%0t",
                         local_out_data[DST_ID], $time);
                fail_count++;
            end

            for (int d = 0; d < 15; d++) begin
                if (local_out_vld[d] && local_out_rdy[d]) begin
                    $display("FAIL: late wrong destination dst=%0d pkt=0x%0h time=%0t",
                             d, local_out_data[d], $time);
                    fail_count++;
                end
            end
        end

        $display("--------------------------------");
        $display("TEST COMPLETE");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);
        $display("RECV = %0d / %0d", recv_count, EXP_PKTS);
        $display("--------------------------------");

        if (fail_count == 0)
            $display("FINAL RESULT: PASS");
        else
            $display("FINAL RESULT: FAIL");

        $finish;
    end

endmodule