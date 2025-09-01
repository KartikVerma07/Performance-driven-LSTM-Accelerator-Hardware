// Sigmoid: 9-bit input -> 8-bit output via LUT (clocked)
// - For input_data < 192  -> output 32
// - For input_data > 320  -> output 96
// - Else (≈192..320)      -> use 128-entry LUT indexed by (input_data - 192)
//   NOTE: LUT has indices [0..127]; ensure input 192..319 maps inside.
module Sigmoid (
    input  logic       clk,
    input  logic       reset_n,
    input  logic [8:0] input_data,
    output logic [7:0] output_data
);

  // 128-entry sigmoid-like lookup (tweak values to shape curve)
  logic [7:0] lut_data [0:127] = '{
    32,33,33,33,33,33,34,34,34,34,34,35,35,35,35,35,
    36,36,36,36,37,37,37,37,38,38,38,38,39,39,39,40, 
    40,40,41,41,41,42,42,43,43,45,45,46,46,47,47,48, 
    49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64, 
    64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79, 
    80,81,81,82,82,83,83,84,84,85,85,86,86,86,87,87,
    87,88,88,88,89,89,89,89,90,90,90,90,91,91,91,91, 
    93,93,93,93,93,94,94,94,94,94,95,95,95,95,95,96
  };

  // Clocked output with async reset
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      output_data <= 8'b00000000;       // reset to 0
    end else begin
      if (input_data < 9'd192)
        output_data <= 8'b00100000;     // 32
      else if (input_data > 9'd320)
        output_data <= 8'b01100000;     // 96
      else
        output_data <= lut_data[input_data - 9'd192]; // LUT for mid-range
    end
  end

endmodule
