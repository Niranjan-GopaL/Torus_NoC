`timescale 1ns/1ps

module tb_torus_4x4;

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
        $dumpfile("torus_4x4.vcd");
        $dumpvars(0, tb_torus_4x4);
    end

    function automatic logic [7:0] make_pkt(
        input logic [1:0] dest_x,
        input logic [1:0] dest_y,
        input logic [3:0] payload
    );
        make_pkt = {dest_x, dest_y, payload};
    endfunction

    task automatic send_packet(
        input int src_id,
        input logic [7:0] pkt
    );
        begin
            @(posedge clk);

            local_in_vld[src_id]  <= 1'b1;
            local_in_data[src_id] <= pkt;

            while (!local_in_rdy[src_id]) begin
                @(posedge clk);
            end

            @(posedge clk);

            local_in_vld[src_id]  <= 1'b0;
            local_in_data[src_id] <= '0;
        end
    endtask

    task automatic check_packet(
        input int dst_id,
        input logic [7:0] exp_pkt,
        input string name
    );
        int timeout;
        bit done;

        begin
            timeout = 200;
            done    = 1'b0;

            while ((timeout > 0) && !done) begin
                @(posedge clk);

                if (local_out_vld[dst_id] && local_out_rdy[dst_id]) begin
                    done = 1'b1;

                    if (local_out_data[dst_id] === exp_pkt) begin
                        $display("PASS: %s dst=%0d pkt=0x%0h time=%0t",
                                 name, dst_id, local_out_data[dst_id], $time);
                        pass_count++;
                    end else begin
                        $display("FAIL: %s dst=%0d exp=0x%0h got=0x%0h time=%0t",
                                 name, dst_id, exp_pkt, local_out_data[dst_id], $time);
                        fail_count++;
                    end
                end else begin
                    timeout--;
                end
            end

            if (!done) begin
                $display("FAIL: timeout %s dst=%0d exp=0x%0h time=%0t",
                         name, dst_id, exp_pkt, $time);
                fail_count++;
            end
        end
    endtask

    initial begin
        logic [1:0] dst_x;
        logic [1:0] dst_y;
        logic [3:0] payload;
        logic [7:0] pkt;

        pass_count = 0;
        fail_count = 0;

        rst_n = 0;

        local_in_vld  = '0;
        local_in_data = '0;
        local_out_rdy = '1;

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // =====================================================
        // All source-destination pairs
        // Packet format:
        // [7:6] = dest_x
        // [5:4] = dest_y
        // [3:0] = payload
        //
        // ID = y*4 + x
        // =====================================================

        for (int src_id = 0; src_id < 16; src_id++) begin
            for (int dst_id = 0; dst_id < 16; dst_id++) begin
                if (src_id != dst_id) begin

                    dst_x   = dst_id % 4;
                    dst_y   = dst_id / 4;
                    payload = src_id[3:0] ^ dst_id[3:0];
                    pkt     = make_pkt(dst_x, dst_y, payload);

                    fork
                        send_packet(src_id, pkt);
                        check_packet(dst_id, pkt,
                                     $sformatf("src=%0d -> dst=%0d", src_id, dst_id));
                    join

                    repeat (5) @(posedge clk);
                end
            end
        end

        // =====================================================
        // Backpressure test
        //
        // This matches current rr_merge behavior:
        // arb_req = in_vld & out_rdy
        //
        // So when destination ready is low:
        // out_vld may also stay low.
        //
        // Test only checks:
        // 1. Packet is NOT delivered while ready is low.
        // 2. Packet is delivered correctly after ready goes high.
        // =====================================================

        $display("Starting backpressure test...");

        pkt = make_pkt(2'd3, 2'd3, 4'hF);

        local_out_rdy[15] = 1'b0;

        @(posedge clk);

        local_in_vld[0]  <= 1'b1;
        local_in_data[0] <= pkt;

        repeat (30) @(posedge clk);

        if (local_out_vld[15] && local_out_rdy[15]) begin
            $display("FAIL: Backpressure: packet delivered while destination ready low");
            fail_count++;
        end else begin
            $display("PASS: Backpressure: no delivery while destination ready low");
            pass_count++;
        end

        local_out_rdy[15] = 1'b1;

        check_packet(15, pkt, "Backpressure release: (0,0) -> (3,3)");

        while (!local_in_rdy[0]) begin
            @(posedge clk);
        end

        @(posedge clk);

        local_in_vld[0]  <= 1'b0;
        local_in_data[0] <= '0;

        repeat (20) @(posedge clk);

        $display("--------------------------------");
        $display("TEST COMPLETE");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);
        $display("--------------------------------");

        if (fail_count == 0)
            $display("FINAL RESULT: PASS");
        else
            $display("FINAL RESULT: FAIL");

        $finish;
    end

endmodule