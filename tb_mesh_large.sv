`timescale 1ns/1ps

module tb_mesh_4x4_random_bp_10k;

    localparam int NUM_NODES   = 16;
    localparam int TOTAL_PKTS  = 20000;
    localparam int PKTS_PER_SRC = TOTAL_PKTS / NUM_NODES; // 625 each
    localparam int EXP_PKTS    = NUM_NODES * PKTS_PER_SRC;
    localparam int MAX_CYCLES  = 500000;

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
    int total_recv_count;
    int total_send_count;

    int exp_count      [0:NUM_NODES-1][0:15];
    int recv_count_arr [0:NUM_NODES-1][0:15];

    mesh_4x4 dut (
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
        $dumpfile("mesh_4x4_random_bp_10k.vcd");
        $dumpvars(0, tb_mesh_4x4_random_bp_10k);
    end

    function automatic logic [7:0] make_pkt(
        input logic [1:0] dest_x,
        input logic [1:0] dest_y,
        input logic [3:0] payload
    );
        make_pkt = {dest_x, dest_y, payload};
    endfunction

    function automatic logic [7:0] get_out_data(input int idx);
        begin
            case (idx)
                0:  get_out_data = local_out_data[0];
                1:  get_out_data = local_out_data[1];
                2:  get_out_data = local_out_data[2];
                3:  get_out_data = local_out_data[3];
                4:  get_out_data = local_out_data[4];
                5:  get_out_data = local_out_data[5];
                6:  get_out_data = local_out_data[6];
                7:  get_out_data = local_out_data[7];
                8:  get_out_data = local_out_data[8];
                9:  get_out_data = local_out_data[9];
                10: get_out_data = local_out_data[10];
                11: get_out_data = local_out_data[11];
                12: get_out_data = local_out_data[12];
                13: get_out_data = local_out_data[13];
                14: get_out_data = local_out_data[14];
                15: get_out_data = local_out_data[15];
                default: get_out_data = '0;
            endcase
        end
    endfunction

    task automatic send_src(input int src_id);
        int dst_id;
        int dst_x;
        int dst_y;
        int payload;
        logic [7:0] pkt;

        begin
            @(negedge clk);

            for (int p = 0; p < PKTS_PER_SRC; p++) begin

                dst_id = $urandom_range(0, 15);

                while (dst_id == src_id) begin
                    dst_id = $urandom_range(0, 15);
                end

                dst_x   = dst_id % 4;
                dst_y   = dst_id / 4;
                payload = $urandom_range(0, 15);

                pkt = make_pkt(dst_x[1:0], dst_y[1:0], payload[3:0]);

                exp_count[dst_id][payload]++;

                local_in_vld[src_id]  = 1'b1;
                local_in_data[src_id] = pkt;

                @(posedge clk);

                while (!local_in_rdy[src_id]) begin
                    @(posedge clk);
                end

                total_send_count++;

                @(negedge clk);
            end

            local_in_vld[src_id]  = 1'b0;
            local_in_data[src_id] = '0;
        end
    endtask

    initial begin
        int sim_cycles;
        logic [7:0] rx_pkt;
        logic [1:0] rx_dst_x;
        logic [1:0] rx_dst_y;
        logic [3:0] rx_payload;
        int pkt_dst_id;

        pass_count       = 0;
        fail_count       = 0;
        total_recv_count = 0;
        total_send_count = 0;

        rst_n = 0;
        local_in_vld  = '0;
        local_in_data = '0;
        local_out_rdy = '1;

        for (int d = 0; d < NUM_NODES; d++) begin
            for (int p = 0; p < 16; p++) begin
                exp_count[d][p]      = 0;
                recv_count_arr[d][p] = 0;
            end
        end

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        $display("Starting 10K random traffic with random backpressure...");
        $display("Expected packets = %0d", EXP_PKTS);

        fork
            send_src(0);
            send_src(1);
            send_src(2);
            send_src(3);
            send_src(4);
            send_src(5);
            send_src(6);
            send_src(7);
            send_src(8);
            send_src(9);
            send_src(10);
            send_src(11);
            send_src(12);
            send_src(13);
            send_src(14);
            send_src(15);

            begin
                while (total_recv_count < EXP_PKTS) begin
                    @(negedge clk);

                    for (int i = 0; i < NUM_NODES; i++) begin
                        // 80% ready, 20% backpressure
                        local_out_rdy[i] = ($urandom_range(0, 4) != 0);
                    end
                end

                local_out_rdy = '1;
            end
        join_none

        sim_cycles = 0;

        while ((total_recv_count < EXP_PKTS) && (sim_cycles < MAX_CYCLES)) begin
            @(posedge clk);
            sim_cycles++;

            for (int d = 0; d < NUM_NODES; d++) begin
                if (local_out_vld[d] && local_out_rdy[d]) begin

                    rx_pkt     = get_out_data(d);
                    rx_dst_x   = rx_pkt[7:6];
                    rx_dst_y   = rx_pkt[5:4];
                    rx_payload = rx_pkt[3:0];

                    pkt_dst_id = rx_dst_y * 4 + rx_dst_x;

                    if (pkt_dst_id != d) begin
                        $display("FAIL: wrong destination arrived=%0d pkt_dst=%0d pkt=0x%0h time=%0t",
                                 d, pkt_dst_id, rx_pkt, $time);
                        fail_count++;
                    end else begin
                        recv_count_arr[d][rx_payload]++;
                        total_recv_count++;

                        if ((total_recv_count % 1000) == 0) begin
                            $display("[%0t] Progress RX=%0d / %0d",
                                     $time, total_recv_count, EXP_PKTS);
                        end
                    end
                end
            end
        end

        local_out_rdy = '1;

        if (total_send_count != EXP_PKTS) begin
            $display("FAIL: expected sent %0d packets, sent %0d",
                     EXP_PKTS, total_send_count);
            fail_count++;
        end else begin
            $display("PASS: sent all %0d packets", EXP_PKTS);
            pass_count++;
        end

        if (total_recv_count != EXP_PKTS) begin
            $display("FAIL: expected received %0d packets, received %0d",
                     EXP_PKTS, total_recv_count);
            fail_count++;
        end else begin
            $display("PASS: received all %0d packets", EXP_PKTS);
            pass_count++;
        end

        for (int d = 0; d < NUM_NODES; d++) begin
            for (int p = 0; p < 16; p++) begin
                if (recv_count_arr[d][p] != exp_count[d][p]) begin
                    $display("FAIL: dst=%0d payload=0x%0h expected=%0d received=%0d",
                             d, p, exp_count[d][p], recv_count_arr[d][p]);
                    fail_count++;
                end
            end
        end

        repeat (100) @(posedge clk);

        $display("--------------------------------");
        $display("TEST COMPLETE");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);
        $display("SENT = %0d / %0d", total_send_count, EXP_PKTS);
        $display("RECV = %0d / %0d", total_recv_count, EXP_PKTS);
        $display("CYCLES = %0d", sim_cycles);
        $display("--------------------------------");

        if (fail_count == 0)
            $display("FINAL RESULT: PASS");
        else
            $display("FINAL RESULT: FAIL");

        $finish;
    end

endmodule
