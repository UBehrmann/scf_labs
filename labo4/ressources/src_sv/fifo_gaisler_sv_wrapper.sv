
module fifo_gaisler_sv_wrapper #(int FIFOSIZE=4, int DATASIZE=1)(
    input  logic              clk_i,
    input  logic              rst_i,
    output logic              full_o,
    output logic              empty_o,
    input  logic              wr_i,
    input  logic              rd_i,
    input  logic[DATASIZE-1:0] wr_data_i,
    output logic[DATASIZE-1:0] rd_data_o
);

    fifo_gaisler #(FIFOSIZE, DATASIZE) dut (.*);

    bind dut fifo_assertions #(FIFOSIZE, DATASIZE) binded (.*);

endmodule
