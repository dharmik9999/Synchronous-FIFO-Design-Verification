`timescale 1ns/1ps
`default_nettype none

// Single-clock FIFO. Valid parameters: DATA_WIDTH >= 1 and DEPTH >= 1.
// Acceptance depends on occupancy BEFORE the rising edge. See PROJECT_SPEC.md.
module sync_fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH = 16
) (
    input  wire clk,
    input  wire rst_n,
    input  wire wr_en,
    input  wire rd_en,
    input  wire [DATA_WIDTH-1:0] din,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire full,
    output wire empty,
    output reg  [((DEPTH < 2) ? 1 : $clog2(DEPTH+1))-1:0] count,
    output reg  overflow,
    output reg  underflow
);
    localparam integer PTR_WIDTH = (DEPTH < 2) ? 1 : $clog2(DEPTH);
    localparam integer COUNT_WIDTH = (DEPTH < 2) ? 1 : $clog2(DEPTH+1);
    localparam integer LAST_ADDR = DEPTH - 1;
    localparam [PTR_WIDTH-1:0] PTR_ONE = {{(PTR_WIDTH-1){1'b0}}, 1'b1};
    localparam [COUNT_WIDTH-1:0] COUNT_ONE = {{(COUNT_WIDTH-1){1'b0}}, 1'b1};

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] wr_ptr;
    reg [PTR_WIDTH-1:0] rd_ptr;
    wire read_accept;
    wire write_accept;

    assign empty = (count == {COUNT_WIDTH{1'b0}});
    assign full = (count == DEPTH[COUNT_WIDTH-1:0]);
    assign read_accept = rd_en && !empty;
    assign write_accept = wr_en && (!full || read_accept);

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= {PTR_WIDTH{1'b0}};
            rd_ptr <= {PTR_WIDTH{1'b0}};
            count <= {COUNT_WIDTH{1'b0}};
            dout <= {DATA_WIDTH{1'b0}};
            overflow <= 1'b0;
            underflow <= 1'b0;
        end else begin
            // Per-cycle rejected-request indicators; not sticky flags.
            overflow <= wr_en && !write_accept;
            underflow <= rd_en && !read_accept;

            if (write_accept) begin
                mem[wr_ptr] <= din;
                if (wr_ptr == LAST_ADDR[PTR_WIDTH-1:0])
                    wr_ptr <= {PTR_WIDTH{1'b0}};
                else
                    wr_ptr <= wr_ptr + PTR_ONE;
            end

            if (read_accept) begin
                // Nonblocking assignments read the pre-edge word, including
                // full-FIFO replacement at the same address (also DEPTH=1).
                // A target RAM implementation must preserve this old-data rule.
                dout <= mem[rd_ptr];
                if (rd_ptr == LAST_ADDR[PTR_WIDTH-1:0])
                    rd_ptr <= {PTR_WIDTH{1'b0}};
                else
                    rd_ptr <= rd_ptr + PTR_ONE;
            end

            case ({write_accept, read_accept})
                2'b10: count <= count + COUNT_ONE;
                2'b01: count <= count - COUNT_ONE;
                default: count <= count;
            endcase
        end
    end
endmodule

`default_nettype wire
