// -----------------------------------------------------------------------------
// Matrix-Vector Multiply with Saturation (element width N, S terms)
// v = satN( sum_{i=0..S-1} satN( w[i] * u[i] ) )
//
// Notes:
// - Inputs are presented as packed buses containing S elements of N bits each.
// - One pipeline stage on inputs (w_r/u_r). Output is purely combinational
//   from those regs (overall latency = 1 cycle).
// - Internal style uses unpacked arrays for readability.
// -----------------------------------------------------------------------------
module mvm_normal_mul #(
  parameter int N = 8,   // element bit-width
  parameter int S = 8    // number of terms in the dot-product
)(
  input  logic               CLOCK_50,
  input  logic               reset_n,      // active-low synchronous reset
  input  logic [S*N-1:0]     w,            // S elements concatenated, each N bits
  input  logic [S*N-1:0]     u,            // S elements concatenated, each N bits
  output logic [N-1:0]       v             // saturated N-bit result
);

  // ---------------------------------------------------------------------------
  // Local typedefs and constants
  // ---------------------------------------------------------------------------
  localparam int P = 2*N;                        // product width before saturation
  localparam logic [N-1:0] N_MAX = {N{1'b1}};    // max N-bit value (e.g. 8'hFF)

  typedef logic [N-1:0]      elem_t;
  typedef logic [P-1:0]      prod_t;

  // ---------------------------------------------------------------------------
  // Registered, unpacked views of inputs for clarity
  // ---------------------------------------------------------------------------
  elem_t w_r [S];
  elem_t u_r [S];

  // Unpack helpers
  function automatic elem_t slice_elem(input logic [S*N-1:0] bus, input int idx);
    // idx = 0 selects [N-1:0], idx = 1 selects [2*N-1:N], etc.
    return bus[(idx+1)*N-1 -: N];
  endfunction

  // Register input vectors and unpack to arrays
  always_ff @(posedge CLOCK_50) begin
    if (!reset_n) begin
      for (int i = 0; i < S; i++) begin
        w_r[i] <= '0;
        u_r[i] <= '0;
      end
    end else begin
      for (int i = 0; i < S; i++) begin
        w_r[i] <= slice_elem(w, i);
        u_r[i] <= slice_elem(u, i);
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Saturating arithmetic helpers
  // ---------------------------------------------------------------------------
  // satN(product) : clamp P-bit product to N bits (0..N_MAX)
  function automatic elem_t sat_prod(input prod_t x);
    if (x[P-1 -: (P-N)] != '0) begin
      // any high bits beyond N imply overflow for unsigned
      return N_MAX;
    end else begin
      return elem_t'(x[N-1:0]);
    end
  endfunction

  // satN(a + b) : clamp N+1-bit sum to N bits
  function automatic elem_t sat_addN(input elem_t a, input elem_t b);
  logic [N:0] sum_ext;
  sum_ext = {1'b0, a} + {1'b0, b};   // proper N+1-bit add
  return sum_ext[N] ? N_MAX : elem_t'(sum_ext[N-1:0]);
endfunction


  // ---------------------------------------------------------------------------
  // Elementwise multiply with saturation, then saturated accumulation
  // ---------------------------------------------------------------------------
  elem_t mul_sat [S];
  elem_t acc;

  always_comb begin
    // 1) elementwise products with saturation down to N bits
    for (int i = 0; i < S; i++) begin
      prod_t raw_prod;
		raw_prod = prod_t'(w_r[i]) * prod_t'(u_r[i]);
      mul_sat[i] = sat_prod(raw_prod);
    end

    // 2) saturated accumulation of N-bit terms
    acc = mul_sat[0];
    for (int i = 1; i < S; i++) begin
      acc = sat_addN(acc, mul_sat[i]);
    end
  end

  assign v = acc;

endmodule
