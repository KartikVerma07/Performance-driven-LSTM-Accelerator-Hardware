// synthesis translate_off
module tb_proposed;
  timeunit 1ns/1ps; timeprecision 1ps;

  // ---- params ----
  localparam integer N = 8;
  localparam integer S = 8;          // must be even
  localparam integer MAX_RAND = 10;  // random range [0..MAX_RAND]

  // ---- DUT I/O ----
  logic             clk;
  logic             reset_n;
  logic [S*N-1:0]   w_bus;
  logic [S*N-1:0]   u_bus;
  logic [N-1:0]     v_dut;

  // Instantiate your DUT (rename if your module name differs)
  mvm_proposed #(.N(N), .S(S)) dut (
    .CLOCK_50 (clk),
    .reset_n  (reset_n),
    .w        (w_bus),
    .u        (u_bus),
    .v        (v_dut)
  );

  // ---- clock ----
  localparam time TCLK = 20ns;
  initial begin
    clk = 1'b0;
    forever #(TCLK/2) clk = ~clk;
  end

  // ---- reset ----
  task automatic do_reset();
    reset_n = 1'b1; @(negedge clk);
    reset_n = 1'b0; repeat (2) @(posedge clk);
    reset_n = 1'b1; @(posedge clk);
  endtask

  // -------------------- golden model helpers --------------------
  typedef logic [N-1:0] elem_t;

  function automatic elem_t sat_addN(input elem_t a, input elem_t b);
    logic [N:0] sum_ext;
    sum_ext = {1'b0, a} + {1'b0, b};
    if (sum_ext[N]) sat_addN = {N{1'b1}}; else sat_addN = sum_ext[N-1:0];
  endfunction

  function automatic elem_t slice_elem(input logic [S*N-1:0] bus, input integer idx);
    slice_elem = bus[(idx+1)*N-1 -: N];
  endfunction

  // emulates mux_4 behavior
  function automatic elem_t mux4_model(
    input elem_t a, input elem_t b, input logic s0, input logic s1
  );
    logic [N:0] sum_ext;
    sum_ext = {1'b0, a} + {1'b0, b};
    case ({s1, s0})
      2'b00: mux4_model = '0;
      2'b01: mux4_model = a;
      2'b10: mux4_model = b;
      default: mux4_model = sum_ext[N] ? {N{1'b1}} : sum_ext[N-1:0];
    endcase
  endfunction

  // Verilog-style golden model (all declarations at the top, integers for loop vars)
  function automatic elem_t golden_mvm(input logic [S*N-1:0] w_in,
                                       input logic [S*N-1:0] u_in);
    elem_t w_arr [S];
    elem_t u_arr [S];
    elem_t bit_sum [N];
    elem_t acc_b;
    elem_t sel_e;
    elem_t acc;
    integer i;
    integer p_idx;
    integer b_idx;
    integer i0;
    integer i1;

    // unpack inputs
    for (i = 0; i < S; i = i + 1) begin
      w_arr[i] = slice_elem(w_in, i);
      u_arr[i] = slice_elem(u_in, i);
    end

    // per-bit saturated sum across pairs
    for (b_idx = 0; b_idx < N; b_idx = b_idx + 1) begin
      acc_b = '0;
      for (p_idx = 0; p_idx < (S/2); p_idx = p_idx + 1) begin
        i0 = 2*p_idx;
        i1 = i0 + 1;
        sel_e = mux4_model(u_arr[i0], u_arr[i1], w_arr[i0][b_idx], w_arr[i1][b_idx]);
        if (p_idx == 0) acc_b = sel_e;
        else            acc_b = sat_addN(acc_b, sel_e);
      end
      bit_sum[b_idx] = acc_b;
    end

    // final weighted saturated sum
    acc = '0;
    for (b_idx = 0; b_idx < N; b_idx = b_idx + 1) begin
      acc = sat_addN(acc, (bit_sum[b_idx] << b_idx));
    end
    golden_mvm = acc;
  endfunction

  // -------------------- stimulus --------------------
  elem_t w_vec [S];
  elem_t u_vec [S];
  elem_t v_ref;

  task automatic pack_buses();
    integer i;
    w_bus = '0; u_bus = '0;
    for (i = 0; i < S; i = i + 1) begin
      w_bus[(i+1)*N-1 -: N] = w_vec[i];
      u_bus[(i+1)*N-1 -: N] = u_vec[i];
    end
  endtask

  integer trial;
  integer i;

  initial begin
    // optional deterministic seed:
    // int unsigned seed = 32'hFEED_BEEF; void'($urandom(seed));
    do_reset();

    for (trial = 0; trial < 200; trial = trial + 1) begin
      for (i = 0; i < S; i = i + 1) begin
        w_vec[i] = elem_t'($urandom_range(0, MAX_RAND));
        u_vec[i] = elem_t'($urandom_range(0, MAX_RAND));
      end

      // build buses and golden before driving
      pack_buses();
      v_ref = golden_mvm(w_bus, u_bus);

      // drive on negedge so inputs are stable at sampling posedge
      @(negedge clk);
      pack_buses();

      // one cycle for input regs + tiny delta for NBAs
      @(posedge clk); #1ps;

      if (v_dut !== v_ref) begin
        $error("Mismatch t=%0d  v_ref=%0d  v_dut=%0d  w=%p  u=%p",
               trial, v_ref, v_dut, w_vec, u_vec);
      end else if (trial < 5) begin
        $display("[trial %0d] PASS v=%0d  w=%p  u=%p", trial, v_dut, w_vec, u_vec);
      end
    end

    repeat (2) @(posedge clk);
    $display("All tests completed.");
    $finish;
  end

endmodule
// synthesis translate_on
