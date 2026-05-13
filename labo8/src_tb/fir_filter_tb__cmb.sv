//==============================================================================
// File        : fir_filter_tb.sv
// Description : FIR Filter Testbench - Combinational version
//==============================================================================

module fir_filter_tb;

  //--------------------------------------------------------------------------
  // Paramètres
  //--------------------------------------------------------------------------
  localparam ORDER      = 2;
  localparam DATASIZE   = 16;
  localparam COEFFSIZE  = 16;
  localparam COMMAPOS   = 0;

  //--------------------------------------------------------------------------
  // Signaux
  //--------------------------------------------------------------------------
  logic clk_i;
  logic rst_i;

  logic din_valid_i;
  logic signed [DATASIZE-1:0] din_i;
  logic din_ready_o;

  logic signed [COEFFSIZE-1:0] coeffs_i [0:ORDER];

  logic dout_valid_o;
  logic signed [DATASIZE-1:0] dout_o;
  logic dout_ready_i;

  //--------------------------------------------------------------------------
  // DUT
  //--------------------------------------------------------------------------
  fir_filter #(
    .ORDER(ORDER),
    .DATASIZE(DATASIZE),
    .COEFFSIZE(COEFFSIZE),
    .COMMAPOS(COMMAPOS)
  ) dut (
    .clk_i(clk_i),
    .rst_i(rst_i),

    .din_valid_i(din_valid_i),
    .din_i(din_i),
    .din_ready_o(din_ready_o),

    .coeffs_i(coeffs_i),

    .dout_valid_o(dout_valid_o),
    .dout_o(dout_o),
    .dout_ready_i(dout_ready_i)
  );

  //--------------------------------------------------------------------------
  // Clock
  //--------------------------------------------------------------------------
  initial clk_i = 0;
  always #5 clk_i = ~clk_i;

  //--------------------------------------------------------------------------
  // Task : envoi d'une donnée + vérification
  //--------------------------------------------------------------------------
  task send_and_check(
    input signed [DATASIZE-1:0] sample,
    input signed [DATASIZE-1:0] expected
  );
  begin
    @(negedge clk_i);
    din_valid_i = 1'b1;
    din_i       = sample;

    @(posedge clk_i);

    // petit délai pour laisser la logique combinatoire se propager
    #1;

    $display("Expected = %0d | Received = %0d", expected, dout_o);

    if (dout_o !== expected) begin
      $error("[FAILED] Expected %0d but got %0d", expected, dout_o);
      $finish;
    end

    @(negedge clk_i);
    din_valid_i = 1'b0;
  end
  endtask

  //--------------------------------------------------------------------------
  // Stimuli
  //--------------------------------------------------------------------------
  initial begin

    //----------------------------------------------------------------------
    // Init
    //----------------------------------------------------------------------
    rst_i         = 1'b1;
    din_valid_i   = 1'b0;
    din_i         = '0;
    dout_ready_i  = 1'b1;

    //----------------------------------------------------------------------
    // Coefficients
    //----------------------------------------------------------------------
    coeffs_i[0] = 1;
    coeffs_i[1] = 2;
    coeffs_i[2] = 3;

    //----------------------------------------------------------------------
    // Reset
    //----------------------------------------------------------------------
    repeat(5) @(posedge clk_i);
    rst_i = 1'b0;

    //----------------------------------------------------------------------
    // Test
    //
    // x = 2 : y = 2*1 = 2
    // x = 3 : y = 3*1 + 2*2 = 7
    // x = 4 : y = 4*1 + 3*2 + 2*3 = 16
    //----------------------------------------------------------------------
    send_and_check(2, 2);
    send_and_check(3, 7);
    send_and_check(4, 16);

    //----------------------------------------------------------------------
    // Fin
    //----------------------------------------------------------------------
    $display("[PASSED] FIR combinatoire test successful.");
    $finish;
  end

endmodule
