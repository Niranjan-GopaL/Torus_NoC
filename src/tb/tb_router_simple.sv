`timescale 1ns/1ps

module tb_torus_router_simple;

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

    int packet_counter;
    int received_counter;

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

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // VCD dump
    initial begin
        $dumpfile("torus_router_simple.vcd");
        $dumpvars(0, tb_torus_router_simple);
    end

    // Packet generation helper
    function automatic logic [7:0] make_pkt(
        input logic [1:0] dest_x,
        input logic [1:0] dest_y,
        input logic [3:0] payload
    );
        make_pkt = {dest_x, dest_y, payload};
    endfunction

    // Task to send packet with proper valid hold behavior
    task automatic send_packet_continuous(
        input int in_port,
        input logic [7:0] pkt,
        input int packet_id
    );
        begin
            @(posedge clk);
            $display("[%0t] Sending packet %0d on port %0s: data=0x%0h", 
                     $time, packet_id, 
                     (in_port == LOCAL) ? "LOCAL" :
                     (in_port == EAST)  ? "EAST"  :
                     (in_port == WEST)  ? "WEST"  :
                     (in_port == NORTH) ? "NORTH" : "SOUTH",
                     pkt);
            
            // Assert valid and data
            in_vld[in_port]  <= 1'b1;
            in_data[in_port] <= pkt;
            
            // Hold valid until ready is seen
            while (!in_rdy[in_port]) begin
                @(posedge clk);
                // Keep valid and data asserted while waiting
                in_vld[in_port]  <= 1'b1;
                in_data[in_port] <= pkt;
            end
            
            // Ready seen, deassert valid next cycle
            @(posedge clk);
            in_vld[in_port]  <= 1'b0;
            in_data[in_port] <= '0;
            
            $display("[%0t] Packet %0d completed handshake", $time, packet_id);
        end
    endtask

    // Monitor output packets
    task automatic monitor_output();
        forever begin
            @(posedge clk);
            for (int port = 0; port < 5; port++) begin
                if (out_vld[port] && out_rdy[port]) begin
                    received_counter++;
                    $display("[%0t] RECEIVED packet %0d on port %0s: data=0x%0h", 
                             $time, received_counter,
                             (port == LOCAL) ? "LOCAL" :
                             (port == EAST)  ? "EAST"  :
                             (port == WEST)  ? "WEST"  :
                             (port == NORTH) ? "NORTH" : "SOUTH",
                             out_data[port]);
                end
            end
        end
    endtask

    // ============================================
    // GROUP 1: Continuous packets from LOCAL to NORTH
    // ============================================
    task group1_local_to_north();
        logic [7:0] pkt;
        begin
            $display("\n=========================================");
            $display("GROUP 1: Sending continuous packets from LOCAL to NORTH");
            $display("Destination: X=1, Y=2 (NORTH)");
            $display("=========================================\n");
            
            packet_counter = 0;
            
            // Send 10 packets continuously
            for (int i = 0; i < 10; i++) begin
                packet_counter++;
                pkt = make_pkt(2'd1, 2'd2, packet_counter[3:0]); // Dest NORTH (1,2)
                send_packet_continuous(LOCAL, pkt, packet_counter);
                
                // Small delay between packets (optional)
                repeat(2) @(posedge clk);
            end
            
            $display("\n[%0t] GROUP 1 Complete: Sent %0d packets", $time, packet_counter);
            repeat(10) @(posedge clk);
        end
    endtask

    // ============================================
    // GROUP 2: Back-pressure test on NORTH port
    // ============================================
    task group2_backpressure_test();
        logic [7:0] pkt;
        int packets_sent;
        begin
            $display("\n=========================================");
            $display("GROUP 2: Back-pressure test on NORTH port");
            $display("Phase 1: NORTH port NOT READY");
            $display("Phase 2: NORTH port becomes READY");
            $display("=========================================\n");
            
            // Reset first
            $display("[%0t] Applying reset...", $time);
            rst_n = 0;
            out_rdy[NORTH] = 1'b1;  // Default to ready during reset
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
            
            // Phase 1: Make NORTH port not ready
            $display("\n[%0t] PHASE 1: Setting NORTH port NOT READY", $time);
            out_rdy[NORTH] = 1'b0;
            repeat(2) @(posedge clk);
            
            // Start sending packets while NORTH is not ready
            packets_sent = 0;
            $display("[%0t] Starting to send packets while NORTH is blocked...", $time);
            
            fork
                begin
                    // Send 5 packets continuously
                    for (int i = 0; i < 5; i++) begin
                        packets_sent++;
                        pkt = make_pkt(2'd1, 2'd2, packets_sent[3:0]);
                        send_packet_continuous(LOCAL, pkt, packets_sent);
                        
                        // Small gap between packet attempts
                        repeat(3) @(posedge clk);
                    end
                end
                
                begin
                    // Wait some cycles then make NORTH ready
                    repeat(30) @(posedge clk);
                    $display("\n[%0t] PHASE 2: Making NORTH port READY now", $time);
                    out_rdy[NORTH] = 1'b1;
                end
            join
            
            $display("\n[%0t] GROUP 2 Complete: Sent %0d packets during back-pressure test", 
                     $time, packets_sent);
            repeat(10) @(posedge clk);
        end
    endtask

    // Main test sequence
    initial begin
        // Initialize
        rst_n   = 0;
        in_vld  = '0;
        in_data = '0;
        out_rdy = '1;  // All ports ready by default
        packet_counter = 0;
        received_counter = 0;
        
        // Reset sequence
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        // Start monitor
        fork
            monitor_output();
        join_none
        
        // Run GROUP 1
        group1_local_to_north();
        
        // Small break between groups
        repeat(20) @(posedge clk);
        
        // Run GROUP 2
        group2_backpressure_test();
        
        // Final report
        repeat(20) @(posedge clk);
        
        $display("\n=========================================");
        $display("TEST SUMMARY");
        $display("=========================================");
        $display("Packets Sent:     %0d", packet_counter);
        $display("Packets Received: %0d", received_counter);
        
        if (packet_counter == received_counter) begin
            $display("\n✓ FINAL RESULT: PASS");
            $display("  All %0d packets received successfully", packet_counter);
        end else begin
            $display("\n✗ FINAL RESULT: FAIL");
            $display("  Lost %0d packets", packet_counter - received_counter);
        end
        $display("=========================================");
        
        $finish;
    end

    // Optional: Monitor handshake status
    always @(posedge clk) begin
        if (rst_n && in_vld[LOCAL] && !in_rdy[LOCAL]) begin
            $display("[%0t] WARNING: LOCAL port stalled - waiting for ready", $time);
        end
    end

endmodule