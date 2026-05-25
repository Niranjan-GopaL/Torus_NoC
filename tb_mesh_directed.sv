`timescale 1ns/1ps

module tb_torus_4x4_directed;

    logic              clk;
    logic              rst_n;

    logic [15:0]       local_in_vld;
    logic [15:0]       local_in_rdy;
    logic [15:0][7:0]  local_in_data;

    logic [15:0]       local_out_vld;
    logic [15:0]       local_out_rdy;
    logic [15:0][7:0]  local_out_data;

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
        $dumpvars(0, tb_torus_4x4_directed);
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
            timeout = 100;
            done    = 1'b0;

            while ((timeout > 0) && !done) begin
                @(posedge clk);

                if (local_out_vld[dst_id] && local_out_rdy[dst_id]) begin
                    done = 1'b1;

                    if (local_out_data[dst_id] === exp_pkt) begin
                        $display("PASS: %s dst=%0d pkt=0x%0h time=%0t",
                                 name, dst_id, local_out_data[dst_id], $time);
                    end else begin
                        $display("FAIL: %s dst=%0d exp=0x%0h got=0x%0h time=%0t",
                                 name, dst_id, exp_pkt, local_out_data[dst_id], $time);
                    end
                end else begin
                    timeout--;
                end
            end

            if (!done) begin
                $display("FAIL: timeout %s dst=%0d exp=0x%0h time=%0t",
                         name, dst_id, exp_pkt, $time);
            end
        end
    endtask

    initial begin
        rst_n = 0;

        local_in_vld  = '0;
        local_in_data = '0;
        local_out_rdy = '1;

        repeat (5) @(posedge clk);

        rst_n = 1;

        repeat (2) @(posedge clk);

        // Packet format:
        // [7:6] = dest_x
        // [5:4] = dest_y
        // [3:0] = payload
        //
        // ID = y*4 + x

        // (0,0) -> (3,3)
        fork
            send_packet(0,  make_pkt(2'd3, 2'd3, 4'h1));
            check_packet(15, make_pkt(2'd3, 2'd3, 4'h1), "(0,0) -> (3,3)");
        join

        repeat (10) @(posedge clk);

        // (3,3) -> (0,0)
        fork
            send_packet(15, make_pkt(2'd0, 2'd0, 4'h2));
            check_packet(0,  make_pkt(2'd0, 2'd0, 4'h2), "(3,3) -> (0,0)");
        join

        repeat (10) @(posedge clk);

        // (0,3) -> (3,0)
        fork
            send_packet(12, make_pkt(2'd3, 2'd0, 4'h3));
            check_packet(3,  make_pkt(2'd3, 2'd0, 4'h3), "(0,3) -> (3,0)");
        join

        repeat (10) @(posedge clk);

        // (3,0) -> (0,3)
        fork
            send_packet(3,  make_pkt(2'd0, 2'd3, 4'h4));
            check_packet(12, make_pkt(2'd0, 2'd3, 4'h4), "(3,0) -> (0,3)");
        join

        repeat (20) @(posedge clk);

        $display("TEST COMPLETE");
        $finish;
    end

endmodule