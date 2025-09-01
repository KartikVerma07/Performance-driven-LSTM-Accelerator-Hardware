// Tanh_ROM: table lookup for tanh()
// - x is inWidth-bit 2's-complement; map to unsigned addr y; out = mem[y]
module Tanh_ROM #(parameter inWidth=8, dataWidth=8) (
    input                   clk,                    // clock
    input   [inWidth-1:0]   x,                      // signed index (2's comp bits)
    output  [dataWidth-1:0] out                     // ROM output
    );
    
    logic [dataWidth-1:0] mem [2**inWidth-1:0];     // ROM: 2^inWidth entries
    logic [inWidth-1:0]   y;                        // unsigned address

    // Initialize ROM contents (as provided)
    initial begin
        $readmemb("tanhContent.mif", mem);
    end
    
    // Map signed x to unsigned y: add/sub 2^(inWidth-1) (wraps modulo 2^inWidth)
    always @(posedge clk) begin
        if ($signed(x) >= 0)
            y <= x + (2**(inWidth-1));
        else
            y <= x - (2**(inWidth-1));      
    end
    
    // Asynchronous read of ROM
    assign out = mem[y];
    
endmodule
