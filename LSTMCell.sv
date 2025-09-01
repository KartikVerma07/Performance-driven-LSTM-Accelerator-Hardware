// LSTMCell
// - Gate preactivations follow the diagram's form:
//     it = σ( xt·U^i + ht-1·W^i )
//     ft = σ( xt·U^f + ht-1·W^f )
//     ot = σ( xt·U^o + ht-1·W^o )
//     ĝt = tanh( xt·U^g + ht-1·W^g )
//
// - State update:
//     ct = ft * ct1 + it * ĝt
//     ht = ot * tanh(ct)

module LSTMCell (
  input  logic        CLOCK_50,
  input  logic        reset_n,
  input  logic [63:0] xt,    // x_t : packed 8×8-bit vector
  input  logic [7:0]  ct1,   // c_{t-1} : 8-bit scalar (project choice)
  input  logic [63:0] ht1,   // h_{t-1} : packed 8×8-bit vector
  output logic [7:0]  ht,    // h_t : 8-bit scalar
  output logic [7:0]  ct     // c_t : 8-bit scalar
);
  localparam int N = 8, S = 8; // S must be even for mvm_proposed

  // ---------------------------------------------------------------------------
  // Weights (each is an 8×8-bit packed vector).
  // ROM order assumed: 0..7 -> Ui,Uf,Uo,Ug, Wi,Wf,Wo,Wg.
  // ---------------------------------------------------------------------------
  logic [S*N-1:0] Ui, Uf, Uo, Ug;  // "U^?" in diagram (paired with xt)
  logic [S*N-1:0] Wi, Wf, Wo, Wg;  // "W^?" in diagram (paired with ht-1)

  // Initialize weights from small 8x64b ROMs
  iniValues_ROM rom_Ui (.index(3'd0), .data(Ui));
  iniValues_ROM rom_Uf (.index(3'd1), .data(Uf));
  iniValues_ROM rom_Uo (.index(3'd2), .data(Uo));
  iniValues_ROM rom_Ug (.index(3'd3), .data(Ug));
  iniValues_ROM rom_Wi (.index(3'd4), .data(Wi));
  iniValues_ROM rom_Wf (.index(3'd5), .data(Wf));
  iniValues_ROM rom_Wo (.index(3'd6), .data(Wo));
  iniValues_ROM rom_Wg (.index(3'd7), .data(Wg));

  // ---------------------------------------------------------------------------
  // Dot-product results
  // ---------------------------------------------------------------------------
  logic [N-1:0] Wixt, Wfxt, Woxt, Wgxt; 
  logic [N-1:0] Uiht, Ufht, Uoht, Ught;

  // xt · U^? 
  mvm_proposed #(.N(N), .S(S)) u_mvm_Ui (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Ui), .u(xt ), .v(Wixt)); // Wixt ≡ xt·U^i 
  mvm_proposed #(.N(N), .S(S)) u_mvm_Uf (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Uf), .u(xt ), .v(Wfxt)); // Wfxt ≡ xt·U^f
  mvm_proposed #(.N(N), .S(S)) u_mvm_Uo (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Uo), .u(xt ), .v(Woxt)); // Woxt ≡ xt·U^o
  mvm_proposed #(.N(N), .S(S)) u_mvm_Ug (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Ug), .u(xt ), .v(Wgxt)); // Wgxt ≡ xt·U^g

  // ht-1 · W^? 
  mvm_proposed #(.N(N), .S(S)) u_mvm_Wi (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Wi), .u(ht1), .v(Uiht)); // Uiht ≡ ht-1·W^i
  mvm_proposed #(.N(N), .S(S)) u_mvm_Wf (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Wf), .u(ht1), .v(Ufht)); // Ufht ≡ ht-1·W^f
  mvm_proposed #(.N(N), .S(S)) u_mvm_Wo (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Wo), .u(ht1), .v(Uoht)); // Uoht ≡ ht-1·W^o
  mvm_proposed #(.N(N), .S(S)) u_mvm_Wg (.CLOCK_50(CLOCK_50), .reset_n(reset_n), .w(Wg), .u(ht1), .v(Ught)); // Ught ≡ ht-1·W^g

  // ---------------------------------------------------------------------------
  // Gate activations: preact add then activation (Sigmoid for f,i,o; tanh for g~)
  // SigAddSub currently wraps a signed/abs or sum + sigmoid LUT. If you have a
  // Tanh ROM for g~, substitute it here (or parameterize SigAddSub).
  // ---------------------------------------------------------------------------
  logic [N-1:0] ft, it, candt, ot;
  
    // i_t = σ( xt·U^i + ht-1·W^i )
  SigAddSub add_act_i (.clk(CLOCK_50), .reset_n(reset_n),
                       .input_data1(Uiht), .input_data2(Wixt), .output_sum(it));

  // f_t = σ( xt·U^f + ht-1·W^f )
  SigAddSub add_act_f (.clk(CLOCK_50), .reset_n(reset_n),
                       .input_data1(Ufht), .input_data2(Wfxt), .output_sum(ft));
							  
  // o_t = σ( xt·U^o + ht-1·W^o )
  SigAddSub add_act_o (.clk(CLOCK_50), .reset_n(reset_n),
                       .input_data1(Uoht), .input_data2(Woxt), .output_sum(ot));

  // ĝ_t = tanh( xt·U^g + ht-1·W^g )
  // NOTE: using SigAddSub (σ) here only approximates tanh; replace with tanh ROM.
  SigAddSub add_act_g (.clk(CLOCK_50), .reset_n(reset_n),
                       .input_data1(Ught), .input_data2(Wgxt), .output_sum(candt));

  // ---------------------------------------------------------------------------
  // State update:
  //   ct = ft * ct1 + it * ĝt
  //   ht = ot * tanh(ct)
  // Your current cellState may run ct through sigmoid/tanh depending on version.
  // ---------------------------------------------------------------------------
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
