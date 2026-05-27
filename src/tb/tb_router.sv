`timescale 1ns/1ps

module tb_torus_router_5x5;

    localparam int LOCAL = 0;
    localparam int EAST  = 1;
    localparam int WEST  = 2;
    localparam int NORTH = 3;
    localparam int SOUTH = 4;

    logic             clk;
    logic             rst_n;

    logic [4:0]       in_vld;
    logic [4:0]       in_rdy;
    logic [4:0][7:0]  in_data;

    logic [4:0]       out_vld;
    logic [4:0]       out_rdy;
    logic [4:0][7:0]  out_data;

    int pass_count;
    int fail_count;

    torus_router_5x5 #(
        .CURR_X(1),
        .CURR_Y(1)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_vld   (in_vld),
        .in_rdy   (in_rdy),
        .in_data  (in_data),
        .out_vld  (out_vld),
        .out_rdy  (out_rdy),
        .out_data (out_data)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("torus_router_5x5.vcd");
        $dumpvars(0, tb_torus_router_5x5);
    end

    function automatic logic [7:0] make_pkt(
        input logic [1:0] dest_x,
        input logic [1:0] dest_y,
        input logic [3:0] payload
    );
        make_pkt = {dest_x, dest_y, payload};
    endfunction

    task automatic send_packet(
        input int in_port,
        input logic [7:0] pkt
    );
        begin
            @(posedge clk);
            in_vld[in_port]  <= 1'b1;
            in_data[in_port] <= pkt;

            while (!in_rdy[in_port]) begin
                @(posedge clk);
            end

            @(posedge clk);
            in_vld[in_port]  <= 1'b0;
            in_data[in_port] <= '0;
        end
    endtask

    task automatic check_output(
        input int port,
        input logic [7:0] exp_data,
        input string name
    );
        int timeout;
        bit done;

        begin
            timeout = 30;
            done    = 1'b0;

            while ((timeout > 0) && !done) begin
                @(posedge clk);

                if (out_vld[port] && out_rdy[port]) begin
                    done = 1'b1;

                    if (out_data[port] === exp_data) begin
                        $display("PASS: %s | out_port=%0d data=0x%0h time=%0t",
                                 name, port, out_data[port], $time);
                        pass_count++;
                    end else begin
                        $display("FAIL: %s | out_port=%0d exp=0x%0h got=0x%0h time=%0t",
                                 name, port, exp_data, out_data[port], $time);
                        fail_count++;
                    end
                end else begin
                    timeout--;
                end
            end

            if (!done) begin
                $display("FAIL: %s | timeout waiting out_port=%0d exp=0x%0h time=%0t",
                         name, port, exp_data, $time);
                fail_count++;
            end
        end
    endtask

    task automatic directed_test(
        input int in_port,
        input int exp_out_port,
        input logic [1:0] dest_x,
        input logic [1:0] dest_y,
        input logic [3:0] payload,
        input string name
    );
        logic [7:0] pkt;

        begin
            pkt = make_pkt(dest_x, dest_y, payload);

            fork
                send_packet(in_port, pkt);
                check_output(exp_out_port, pkt, name);
            join
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        rst_n   = 0;
        in_vld  = '0;
        in_data = '0;
        out_rdy = '1;

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Router coordinate = (1,1)
        // Packet format:
        // [7:6] = dest_x
        // [5:4] = dest_y
        // [3:0] = payload

        // LOCAL input
        directed_test(LOCAL, EAST,  2'd2, 2'd1, 4'h1,
                      "LOCAL input -> EAST output");
        directed_test(LOCAL, WEST,  2'd0, 2'd1, 4'h2,
                      "LOCAL input -> WEST output");
        directed_test(LOCAL, NORTH, 2'd1, 2'd2, 4'h3,
                      "LOCAL input -> NORTH output");
        directed_test(LOCAL, SOUTH, 2'd1, 2'd0, 4'h4,
                      "LOCAL input -> SOUTH output");

        // EAST input
        directed_test(EAST, LOCAL, 2'd1, 2'd1, 4'h5,
                      "EAST input -> LOCAL output");
        directed_test(EAST, WEST,  2'd0, 2'd1, 4'h7,
                      "EAST input -> WEST output");
        directed_test(EAST, NORTH, 2'd1, 2'd2, 4'h8,
                      "EAST input -> NORTH output");
        directed_test(EAST, SOUTH, 2'd1, 2'd0, 4'h9,
                      "EAST input -> SOUTH output");

        // WEST input
        directed_test(WEST, LOCAL, 2'd1, 2'd1, 4'hA,
                      "WEST input -> LOCAL output");
        directed_test(WEST, EAST,  2'd2, 2'd1, 4'hB,
                      "WEST input -> EAST output");
        directed_test(WEST, NORTH, 2'd1, 2'd2, 4'hD,
                      "WEST input -> NORTH output");
        directed_test(WEST, SOUTH, 2'd1, 2'd0, 4'hE,
                      "WEST input -> SOUTH output");

        // NORTH input
        directed_test(NORTH, LOCAL, 2'd1, 2'd1, 4'h1,
                      "NORTH input -> LOCAL output");
        directed_test(NORTH, EAST,  2'd2, 2'd1, 4'h2,
                      "NORTH input -> EAST output");
        directed_test(NORTH, WEST,  2'd0, 2'd1, 4'h3,
                      "NORTH input -> WEST output");
        directed_test(NORTH, SOUTH, 2'd1, 2'd0, 4'h5,
                      "NORTH input -> SOUTH output");

        // SOUTH input
        directed_test(SOUTH, LOCAL, 2'd1, 2'd1, 4'h6,
                      "SOUTH input -> LOCAL output");
        directed_test(SOUTH, EAST,  2'd2, 2'd1, 4'h7,
                      "SOUTH input -> EAST output");
        directed_test(SOUTH, WEST,  2'd0, 2'd1, 4'h8,
                      "SOUTH input -> WEST output");
        directed_test(SOUTH, NORTH, 2'd1, 2'd2, 4'h9,
                      "SOUTH input -> NORTH output");

        repeat (10) @(posedge clk);

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

    always @(posedge clk) begin
        if (rst_n) begin
            if (out_vld[LOCAL] && out_rdy[LOCAL])
                $display("[%0t] OUT LOCAL data=0x%0h", $time, out_data[LOCAL]);

            if (out_vld[EAST] && out_rdy[EAST])
                $display("[%0t] OUT EAST  data=0x%0h", $time, out_data[EAST]);

            if (out_vld[WEST] && out_rdy[WEST])
                $display("[%0t] OUT WEST  data=0x%0h", $time, out_data[WEST]);

            if (out_vld[NORTH] && out_rdy[NORTH])
                $display("[%0t] OUT NORTH data=0x%0h", $time, out_data[NORTH]);

            if (out_vld[SOUTH] && out_rdy[SOUTH])
                $display("[%0t] OUT SOUTH data=0x%0h", $time, out_data[SOUTH]);
        end
    end

endmodule

