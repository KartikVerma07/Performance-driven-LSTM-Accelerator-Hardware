// LSTMCell
// - Uses your mvm_proposed (N=8,S=8) for the 8-element dot products
// - Gate preacts: Wi·xt, Ui·ht1, etc. → add+activation in SigAddSub
// - State update in cellState: ct = f*ct1 + i*cand ; ht = o*tanh(ct)
module LSTMCell (
  input  logic        CLOCK_50,
  input  logic        reset_n,
  input  logic [63:0] xt,    // x_t : packed 8×8-bit
  input  logic [7:0]  ct1,   // c_{t-1}
  input  logic [63:0] ht1,   // h_{t-1} : packed 8×8-bit
  output logic [7:0]  ht,    // h_t
  output logic [7:0]  ct     // c_t
);
  localparam int N = 8, S = 8; // S must be even for mvm_proposed

  // Weights (packed 8×8-bit)
  logic [S*N-1:0] Ui, Uf, Uo, Ug;
  logic [S*N-1:0] Wi, Wf, Wo, Wg;

  // Initialize weights from ROMs (index selects which vector)
   iniValues_ROM rom_Ui (.index(3'd0), .data(Ui));
	iniValues_ROM rom_Uf (.index(3'd1), .data(Uf));
	iniValues_ROM rom_Uo (.index(3'd2), .data(Uo));
	iniValues_ROM rom_Ug (.index(3'd3), .data(Ug));
	iniValues_ROM rom_Wi (.index(3'd4), .data(Wi));
	iniValues_ROM rom_Wf (.index(3'd5), .data(Wf));
	iniValues_ROM rom_Wo (.index(3'd6), .data(Wo));
	iniValues_ROM rom_Wg (.index(3'd7), .data(Wg));

  // Dot-product results (8-bit, saturated)
  logic [N-1:0] Wixt, Wfxt, Woxt, Wgxt;
  logic [N-1:0] Uiht, Ufht, Uoht, Ught;

  // W? * x_t
  mvm_proposed #(.N(N), .S(S)) u_mvm_Wi (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Wi), .u(xt ), .v(Wixt));
  mvm_proposed #(.N(N), .S(S)) u_mvm_Wf (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Wf), .u(xt ), .v(Wfxt));
  mvm_proposed #(.N(N), .S(S)) u_mvm_Wo (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Wo), .u(xt ), .v(Woxt));
  mvm_proposed #(.N(N), .S(S)) u_mvm_Wg (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Wg), .u(xt ), .v(Wgxt));

  // U? * h_{t-1}
  mvm_proposed #(.N(N), .S(S)) u_mvm_Ui (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Ui), .u(ht1), .v(Uiht));
  mvm_proposed #(.N(N), .S(S)) u_mvm_Uf (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Uf), .u(ht1), .v(Ufht));
  mvm_proposed #(.N(N), .S(S)) u_mvm_Uo (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Uo), .u(ht1), .v(Uoht));
  mvm_proposed #(.N(N), .S(S)) u_mvm_Ug (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Ug), .u(ht1), .v(Ught));

  // Gate activations: add pair then apply Activation fn inside SigAddSub
  logic [N-1:0] ft, it, candt, ot;
  SigAddSub add_act_f (.clk(CLOCK_50), .reset_n(reset_n), .input_data1(Ufht), .input_data2(Wfxt), .output_sum(ft));     // f = σ(Uf·ht1 + Wf·xt)
  SigAddSub add_act_i (.clk(CLOCK_50), .reset_n(reset_n), .input_data1(Uiht), .input_data2(Wixt), .output_sum(it));     // i = σ(Ui·ht1 + Wi·xt)
  SigAddSub add_act_g (.clk(CLOCK_50), .reset_n(reset_n), .input_data1(Ught), .input_data2(Wgxt), .output_sum(candt));  // g̃ = tanh(Ug·ht1 + Wg·xt)
  SigAddSub add_act_o (.clk(CLOCK_50), .reset_n(reset_n), .input_data1(Uoht), .input_data2(Woxt), .output_sum(ot));     // o = σ(Uo·ht1 + Wo·xt)

  // State update: ct, ht
  cellState u_state (
    .clk    (CLOCK_50),
    .reset_n(reset_n),
    .ft     (ft),
    .ct1    (ct1),
    .it     (it),
    .candt  (candt),
    .ot     (ot),
    .ht     (ht),
    .ct     (ct)
  );

endmodule
