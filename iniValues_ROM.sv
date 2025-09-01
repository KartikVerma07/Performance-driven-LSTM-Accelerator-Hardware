// iniValues_ROM: small ROM that returns a 64-bit vector selected by index
// - mem has 8 entries of 64 bits each, initialized from values.txt (hex)
// - combinational read: data = mem[index]
module iniValues_ROM ( 
    input  logic [2:0]  index,         // address (currently 1-bit)
    output logic [63:0] data          // selected 64-bit value
);

  logic [63:0] mem [0:7];             // 8×64-bit ROM

  // Initialize ROM contents from hex text file at simulation start
  initial begin
	$readmemh("E:/MastersVT/Spring_2024/ECE 5545 Advanced VLSI Design/FinalProject2.0/LSTMCell/LSTMCell/values.txt", mem);
  end

  // Combinational read
  assign data = mem[index];

endmodule
