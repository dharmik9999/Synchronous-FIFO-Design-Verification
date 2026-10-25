`timescale 1ns/1ps
`default_nettype none

module tb_sync_fifo;
    parameter integer DATA_WIDTH = 8;
    parameter integer DEPTH = 16;
    localparam integer COUNT_WIDTH = (DEPTH < 2) ? 1 : $clog2(DEPTH+1);
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg wr_en = 0;
    reg rd_en = 0;
    reg [DATA_WIDTH-1:0] din = 0;
    wire [DATA_WIDTH-1:0] dout;
    wire full, empty, overflow, underflow;
    wire [COUNT_WIDTH-1:0] count;

    // Yosys exports a specialized module with parameters already resolved.
`ifdef NETLIST
    sync_fifo dut (
`else
    sync_fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
`endif
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en),
        .din(din), .dout(dout), .full(full), .empty(empty),
        .count(count), .overflow(overflow), .underflow(underflow)
    );

    // Independent model: compact oldest-first array, shifted on each pop.
    // There are no reference read/write pointers and no circular indexing.
    reg [DATA_WIDTH-1:0] model [0:DEPTH-1];
    integer occupancy = 0;
    reg [DATA_WIDTH-1:0] expected_dout = 0;
    reg expected_overflow = 0, expected_underflow = 0;
    integer cycles = 0, writes = 0, reads = 0, resets = 0;
    integer rejected_writes = 0, rejected_reads = 0;
    integer simultaneous_empty = 0, simultaneous_full = 0, simultaneous_middle = 0;
    integer became_full = 0, became_empty = 0, reset_busy = 0;
    integer held_outputs = 0;
    integer combinations [0:2][0:3];
    integer levels [0:DEPTH];
    integer seed = 1, random_cycles = 5000;
    reg [31:0] rng;
    reg [31:0] control;
    reg [DATA_WIDTH-1:0] random_data;
    integer i, j, k;
    reg inject_error;
    string vcd_path;

    // Explicit xorshift32 avoids simulator-specific $random streams.
    function automatic [31:0] next_random(input [31:0] value);
        reg [31:0] x;
        begin
            x = value ^ (value << 13);
            x = x ^ (x >> 17);
            next_random = x ^ (x << 5);
        end
    endfunction

    task automatic check_outputs(input string label_text);
        begin
            if (dout !== expected_dout || count !== COUNT_WIDTH'(occupancy) ||
                full !== (occupancy == DEPTH) || empty !== (occupancy == 0) ||
                overflow !== expected_overflow || underflow !== expected_underflow) begin
                $display("FAIL %s cycle=%0d W=%0d D=%0d seed=%0d", label_text, cycles, DATA_WIDTH, DEPTH, seed);
                $display(" actual dout=%h count=%0d full=%b empty=%b ov=%b un=%b", dout,count,full,empty,overflow,underflow);
                $display(" expect dout=%h count=%0d full=%b empty=%b ov=%b un=%b", expected_dout,occupancy,occupancy==DEPTH,occupancy==0,expected_overflow,expected_underflow);
                $fatal(1, "Scoreboard mismatch");
            end
        end
    endtask

    task automatic step(input bit reset_n, input bit write_req, input bit read_req,
                        input reg [DATA_WIDTH-1:0] data, input string label_text);
        integer before_count, category, index;
        bit pop_ok, push_ok;
        begin
            @(negedge clk);
            rst_n = reset_n;
            wr_en = write_req;
            rd_en = read_req;
            din = data;
            // Synchronous reset and outputs must not respond between edges.
            #1;
            if (cycles > 0) check_outputs({label_text, " before edge"});
            before_count = occupancy;
            @(posedge clk);
            if (!reset_n) begin
                resets = resets + 1;
                if (before_count != 0) reset_busy = reset_busy + 1;
                occupancy = 0;
                expected_dout = 0;
                expected_overflow = 0;
                expected_underflow = 0;
            end else begin
                category = (before_count == 0) ? 0 : ((before_count == DEPTH) ? 2 : 1);
                combinations[category][{write_req,read_req}] = combinations[category][{write_req,read_req}] + 1;
                // Pop uses the ORIGINAL population. Only then can push use space.
                pop_ok = read_req && (before_count > 0);
                if (pop_ok) begin
                    expected_dout = model[0];
                    for (index = 0; index < occupancy-1; index = index+1)
                        model[index] = model[index+1];
                    occupancy = occupancy - 1;
                    reads = reads + 1;
                end else held_outputs = held_outputs + 1;
                push_ok = write_req && (occupancy < DEPTH);
                if (push_ok) begin
                    model[occupancy] = data;
                    occupancy = occupancy + 1;
                    writes = writes + 1;
                end
                expected_overflow = write_req && !push_ok;
                expected_underflow = read_req && !pop_ok;
                if (expected_overflow) rejected_writes = rejected_writes + 1;
                if (expected_underflow) rejected_reads = rejected_reads + 1;
                if (write_req && read_req) begin
                    if (category == 0) simultaneous_empty = simultaneous_empty + 1;
                    if (category == 1) simultaneous_middle = simultaneous_middle + 1;
                    if (category == 2) simultaneous_full = simultaneous_full + 1;
                end
                if (before_count != DEPTH && occupancy == DEPTH) became_full = became_full + 1;
                if (before_count != 0 && occupancy == 0) became_empty = became_empty + 1;
            end
            cycles = cycles + 1;
            levels[occupancy] = levels[occupancy] + 1;
            #1; // Check after nonblocking RTL updates, never in the active-region race.
            if (inject_error && cycles == 5) expected_dout = ~expected_dout;
            check_outputs(label_text);
        end
    endtask

    task automatic fill;
        begin
            while (occupancy < DEPTH)
                step(1, 1, 0, DATA_WIDTH'(occupancy + cycles), "fill/order");
        end
    endtask
    task automatic drain;
        begin
            while (occupancy > 0) step(1, 0, 1, 0, "drain/order");
        end
    endtask

    initial begin
        if (DATA_WIDTH < 1 || DEPTH < 1) $fatal(1, "Parameters must be positive");
        if ($value$plusargs("SEED=%d", seed)) begin end
        if ($value$plusargs("CYCLES=%d", random_cycles)) begin end
        if (random_cycles < 0) $fatal(1, "CYCLES must be nonnegative");
        inject_error = $test$plusargs("INJECT_ERROR");
        rng = (seed == 0) ? 32'h1 : 32'(seed);
        for (i=0; i<3; i=i+1)
            for (j=0; j<4; j=j+1) combinations[i][j] = 0;
        for (i=0; i<=DEPTH; i=i+1) levels[i] = 0;
        if ($value$plusargs("VCD=%s", vcd_path)) begin
            $dumpfile(vcd_path);
            $dumpvars(0, tb_sync_fifo);
        end
        step(0,1,1,'1,"reset priority");
        step(0,0,0,0,"reset held");
        step(1,0,0,0,"empty idle");
        step(1,0,1,0,"empty underflow");
        step(1,0,1,0,"consecutive underflow");
        step(1,0,0,0,"error clears");
        step(1,1,0,DATA_WIDTH'('hA5),"single write");
        step(1,0,0,0,"registered output hold");
        step(1,0,1,0,"single read");
        step(1,1,1,DATA_WIDTH'('h3C),"empty simultaneous no bypass");
        drain();
        // Exercise every request pair in empty, full, and (if possible) middle.
        for (i=0; i<4; i=i+1) begin
            drain();
            step(1,i[1],i[0],DATA_WIDTH'(i+7),"empty request matrix");
            fill();
            step(1,i[1],i[0],DATA_WIDTH'(i+11),"full request matrix");
            if (DEPTH > 1) begin
                drain();
                step(1,1,0,DATA_WIDTH'(i+15),"middle prepare");
                step(1,i[1],i[0],DATA_WIDTH'(i+19),"middle request matrix");
            end
        end
        for (k=0; k<4; k=k+1) begin
            fill();
            step(1,1,0,'1,"overflow preserves contents");
            step(1,1,0,0,"consecutive overflow");
            step(1,0,0,0,"overflow clears");
            // More than two entire revolutions while full, with collisions.
            for (j=0; j<2*DEPTH+3; j=j+1)
                step(1,1,1,DATA_WIDTH'(j+31*k),"full streaming/wrap");
            drain();
            step(1,0,1,0,"empty after drain");
        end
        fill();
        step(0,1,1,'1,"reset during full transaction");
        step(1,0,1,0,"no stale word after reset");
        step(1,1,0,'1,"write after reset");
        step(0,0,1,0,"reset during read");
        fill();
        drain();
        $display("PASS directed W=%0d D=%0d",DATA_WIDTH,DEPTH);

        for (i=0; i<random_cycles; i=i+1) begin
            rng = next_random(rng);
            control = rng;
            // Generate all bits, including widths above 32 bits.
            for (j=0; j<DATA_WIDTH; j=j+1) begin
                rng = next_random(rng);
                random_data[j] = rng[0];
            end
            step(control[11:2] != 0, control[1], control[0], random_data,"random");
        end
        drain();
        step(1,0,0,0,"final idle");

        for (i=0; i<3; i=i+1) begin
            if (!(DEPTH == 1 && i == 1))
                for (j=0; j<4; j=j+1)
                    if (combinations[i][j] == 0) $fatal(1,"Missing request/state bin %0d/%0d",i,j);
        end
        for (i=0; i<=DEPTH; i=i+1)
            if (levels[i] == 0) $fatal(1,"Missing occupancy %0d",i);
        if (writes < 4*DEPTH || reads < 4*DEPTH || reset_busy < 2 ||
            became_full < 4 || became_empty < 4 || rejected_writes == 0 || rejected_reads == 0 ||
            simultaneous_empty == 0 || simultaneous_full == 0 || held_outputs == 0)
            $fatal(1,"Missing directed coverage");
        $display("COVERAGE writes=%0d reads=%0d resets=%0d reset_busy=%0d overflow=%0d underflow=%0d both_empty=%0d both_full=%0d both_middle=%0d to_full=%0d to_empty=%0d held=%0d",writes,reads,resets,reset_busy,rejected_writes,rejected_reads,simultaneous_empty,simultaneous_full,simultaneous_middle,became_full,became_empty,held_outputs);
        $display("PASS W=%0d D=%0d SEED=%0d RANDOM=%0d CHECKED=%0d", DATA_WIDTH, DEPTH, seed, random_cycles, cycles);
        $finish;
    end

    initial begin
        #100000000;
        $fatal(1,"Watchdog timeout");
    end
endmodule

`default_nettype wire
