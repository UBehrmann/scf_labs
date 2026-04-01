


module fifo_assertions #(int FIFOSIZE=8, int DATASIZE=8)(
    input logic clk_i,
    input logic rst_i,
    input logic full_o,
    input logic empty_o,
    input logic wr_i,
    input logic rd_i,
    input logic[DATASIZE-1:0] wr_data_i,
    input logic[DATASIZE-1:0] rd_data_o
);

    // If a write occurs, the FIFO can not be empty the next clock cycle
    assert_not_empty_after_write : assert property ( @(posedge clk_i)  (
        (wr_i) |=> !empty_o));

    // The following disable reads when FIFO is empty
    assume property ( @(posedge clk_i) (!(rd_i & empty_o)));

    // The following disable write when FIFO is full
    assume property ( @(posedge clk_i) (!(wr_i & full_o)));

    int wcnt = 0;
    int rcnt = 0;

    // The following assume ensures the end of the evaluation process
    // Without it the solver can not formally check the design
    assume property ( @(posedge clk_i) (wcnt < 4*FIFOSIZE));

    always @(posedge clk_i or posedge rst_i)
        if (rst_i)
            wcnt = 0;
        else if (wr_i)
            wcnt = (wcnt + 1);

    always @(posedge clk_i or posedge rst_i)
        if (rst_i)
            rcnt = 0;
        else if (rd_i)
            rcnt = (rcnt + 1);

/*
    // The following assertion is not supported by QuestaFormal.
    // Should be allright in simulation.
    property p_data_integrity;
        int cnt;
        logic[DATASIZE-1:0] data;
        @(posedge clk_i)
            (wr_i, cnt=wcnt, data=wr_data_i) |=>
        @(posedge clk_i)
            first_match(##[0:$] (rd_i & (rcnt==cnt)))
            ##0 (rd_data_o==data);
    endproperty
    as3: assert property (p_data_integrity);
*/

    property p_full;
        @(posedge clk_i)
            ( full_o == (wcnt == rcnt + FIFOSIZE) );
    endproperty

    assert_full : assert property (p_full);


    property p_empty;
        @(posedge clk_i)
            ( empty_o == (wcnt == rcnt) );
    endproperty

    assert_empty : assert property (p_empty);


    property p_data_integrity;
        int cnt;
        logic[DATASIZE-1:0] data;
        @(posedge clk_i)
            (wr_i, cnt=wcnt, data=wr_data_i) |=>
            ((##[0:$] (rd_i & (rcnt==cnt))) |->
             (rd_data_o==data));
    endproperty

    assert_data_integrity: assert property (p_data_integrity);

endmodule
