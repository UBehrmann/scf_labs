
module fifo_sv_wrapper #(int FIFOSIZE=4, int DATASIZE=1)(
    input logic clk_i,
    input logic rst_i,
    output logic full_o,
    output logic empty_o,
    input logic wr_i,
    input logic rd_i,
    input logic[DATASIZE-1:0] wr_data_i,
    output logic[DATASIZE-1:0] rd_data_o
);

    fifo#(FIFOSIZE,DATASIZE) dut(.*);

// Instanciation could be used instead of binding
//  edge_detector_assertions assertions(.*);

    bind dut fifo_assertions#(FIFOSIZE,DATASIZE) binded(.*);

endmodule
