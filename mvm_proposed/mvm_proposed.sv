module mvm_proposed #(
  parameter int N = 8,
  parameter int S = 8    // must be even
)(
  input  logic             CLOCK_50,
  input  logic             reset_n,
  input  logic [S*N-1:0]   w,
  input  logic [S*N-1:0]   u,
  output logic [N-1:0]     v
);
  localparam int PAIRS = S/2;
  typedef logic [N-1:0] elem_t;

  // Slice helper for packed buses
  function automatic elem_t slice_elem(input logic [S*N-1:0] bus, input int idx);
    return bus[(idx+1)*N-1 -: N]; // idx=0 -> [N-1:0], idx=1 -> [2N-1:N], ...
  endfunction

  // Unsigned N-bit saturated add
  function automatic elem_t sat_addN(input elem_t a, input elem_t b);
    logic [N:0] sum_ext;
    sum_ext = {1'b0, a} + {1'b0, b};
    return sum_ext[N] ? {N{1'b1}} : sum_ext[N-1:0];
  endfunction

  // 4-way select used by DA per bit of two weights
  function automatic elem_t mux4_sel(
    input elem_t a, input elem_t b, input logic s0, input logic s1
  );
    logic [N:0] sum_ext;
    sum_ext = {1'b0, a} + {1'b0, b};
    unique case ({s1, s0})
      2'b00: return '0;
      2'b01: return a;
      2'b10: return b;
      default: return sum_ext[N] ? {N{1'b1}} : sum_ext[N-1:0]; // 11 → sat(a+b)
    endcase
  endfunction

  // Registered, unpacked inputs (stable, single driver)
  elem_t w_arr [S];
  elem_t u_arr [S];

  always_ff @(posedge CLOCK_50) begin
    if (!reset_n) begin
      for (int i = 0; i < S; i++) begin
        w_arr[i] <= '0;
        u_arr[i] <= '0;
      end
    end else begin
      for (int i = 0; i < S; i++) begin
        w_arr[i] <= slice_elem(w, i);
        u_arr[i] <= slice_elem(u, i);
      end
    end
  end

  // Single combinational block for the whole DA MVM
  always_comb begin
    elem_t bit_sum [N];   // per-bit accumulated (across pairs), N-bit saturated
    elem_t acc;           // final saturated sum with bit weights
    int p, b;
    elem_t acc_b, sel;

    // per-bit: sum across PAIRS using mux4_sel
    for (b = 0; b < N; b++) begin
      acc_b = '0;
      for (p = 0; p < PAIRS; p++) begin
        sel   = mux4_sel(u_arr[2*p], u_arr[2*p+1], w_arr[2*p][b], w_arr[2*p+1][b]);
        acc_b = (p == 0) ? sel : sat_addN(acc_b, sel);
      end
      bit_sum[b] = acc_b;
    end

    // final weighted saturated sum over bit positions
    acc = '0;
    for (b = 0; b < N; b++) begin
      acc = sat_addN(acc, (bit_sum[b] << b));
    end
    v = acc;
  end

endmodule
