// SigAddSub: clocked pre-activation → sigmoid
// - Computes an intermediate 9-bit value either as a+b (when input_data2 > 0x3F)
//   or as |a-b|, then feeds it to the Sigmoid block.
module SigAddSub(
    input  logic       clk,
    input  logic       reset_n,
    input  logic [7:0] input_data1,
    input  logic [7:0] input_data2,
    output logic [7:0] output_sum
);

  logic [8:0] intermediate_sum; // 9-bit to hold sum/diff

  // Register intermediate_sum: reset to 0, then sum or absolute difference
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      intermediate_sum <= 8'b00000000;          // reset (note: 8-bit literal to 9-bit reg)
    end else begin
      if (input_data2 > 7'b0111111) begin       // threshold check (7-bit constant)
        intermediate_sum <= input_data1 + input_data2;   // sum (no saturation here)
      end else begin
        if (input_data1 > input_data2)
          intermediate_sum <= input_data1 - input_data2; // |a - b|
        else
          intermediate_sum <= input_data2 - input_data1;
      end
    end
  end

  // Apply sigmoid nonlinearity to the registered pre-activation
  Sigmoid sigmoid_inst (
    .clk        (clk),
    .reset_n    (reset_n),
    .input_data (intermediate_sum),
    .output_data(output_sum)
  );

endmodule
