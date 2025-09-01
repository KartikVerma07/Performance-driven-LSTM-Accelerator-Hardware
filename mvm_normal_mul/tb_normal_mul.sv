// synthesis translate_off
module tb_normal_mul;

  localparam int N = 8;
  localparam int S = 4;
  localparam int MAX_RAND = 10;   // change range as you like

  time TCLK = 20ns;

  // DUT I/O
  logic                 clk;
  logic                 reset_n;
  logic [S*N-1:0]       w_bus;
  logic [S*N-1:0]       u_bus;
  logic [N-1:0]         v_dut;

  // Instantiate DUT
  mvm_normal_mul #(.N(N), .S(S)) dut (
    .CLOCK_50 (clk),
    .reset_n  (reset_n),
    .w        (w_bus),
    .u        (u_bus),
    .v        (v_dut)
  );

  // Clock
  initial begin
    clk = 1'b0;
    forever #(TCLK/2) clk = ~clk;
  end

  // Optional deterministic seeding
  initial begin
    // int unsigned seed = 32'hFEED_BEEF;
    // void'($urandom(seed));
  end

  // Simple reset
  task automatic do_reset();
    reset_n = 1'b1;
    @(negedge clk);
    reset_n = 1'b0;
    repeat (2) @(posedge clk);
    reset_n = 1'b1;
    @(posedge clk);
  endtask

  // Types and constants
  typedef logic [N-1:0]   elem_t;
  typedef logic [2*N-1:0] prod_t;
  localparam elem_t N_MAX = {N{1'b1}};

  // Pack helper
  task automatic set_elem (inout logic [S*N-1:0] bus, input int idx, input elem_t val);
    bus[(idx+1)*N-1 -: N] = val;
  endtask

  // Golden helpers
  function automatic elem_t sat_prod(input prod_t x);
    if (x[2*N-1:N] != '0) return N_MAX;
    else return elem_t'(x[N-1:0]);
  endfunction

  function automatic elem_t sat_addN(input elem_t a, input elem_t b);
    logic [N:0] sum_ext = {1'b0, a} + {1'b0, b};
    return sum_ext[N] ? N_MAX : elem_t'(sum_ext[N-1:0]);
  endfunction

  function automatic elem_t golden_dot(input elem_t w_arr[S], input elem_t u_arr[S]);
    elem_t acc;
    acc = '0;
    for (int i = 0; i < S; i++) begin
      prod_t p = prod_t'(w_arr[i]) * prod_t'(u_arr[i]);
      elem_t m = sat_prod(p);
      if (i == 0) acc = m; else acc = sat_addN(acc, m);
    end
    return acc;
  endfunction

  // Stimulus
  elem_t w_vec [S];
  elem_t u_vec [S];
  elem_t v_ref;

  integer trial, i;

  initial begin
    do_reset();

    for (trial = 0; trial < 100; trial = trial + 1) begin
  // 1) Randomize element arrays
  for (i = 0; i < S; i = i + 1) begin
    w_vec[i] = elem_t'($urandom_range(0, MAX_RAND));
    u_vec[i] = elem_t'($urandom_range(0, MAX_RAND));
  end

  // 2) Compute golden *before* driving buses
  v_ref = golden_dot(w_vec, u_vec);

  // 3) Drive inputs on the *negedge* so they are stable at the next posedge
  @(negedge clk);
  w_bus = '0;
  u_bus = '0;
  for (i = 0; i < S; i = i + 1) begin
    set_elem(w_bus, i, w_vec[i]);
    set_elem(u_bus, i, u_vec[i]);
  end

  // 4) Wait for the DUT to *capture* on posedge and update its combinational output
  @(posedge clk);
  #1ps; // or #1step ? lets NBAs settle and always_comb recompute

  // 5) Compare
  if (v_dut !== v_ref) begin
    $error("Mismatch: trial=%0d  v_ref=%0d  v_dut=%0d  w=%p  u=%p",
           trial, v_ref, v_dut, w_vec, u_vec);
  end else if (trial < 5) begin
    $display("[trial %0d] PASS  ref=%0d dut=%0d  w=%p  u=%p",
             trial, v_ref, v_dut, w_vec, u_vec);
  end
end


    repeat (2) @(posedge clk);
    $display("All tests completed.");
    $finish;
  end

endmodule
// synthesis translate_on

