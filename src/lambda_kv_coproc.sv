// lambda_kv_coproc.sv — Lambda KV-cache COMPRESSION coprocessor (Chipathon 2026).
//
// A compact KV-cache offload engine that FITS the GF180 workshop core with wide
// margin. It is the KV-cache side of the Lambda decode-attention pipeline, minus
// the (area-hungry fp16) MatE/VecU attention math — the HOST does the attention;
// this chip compresses the KV cache and scores token importance. Three hardened
// blocks + the serial loader:
//
//   KVE   cq_value_path_wht_syn : one V token (D fp16 channels, original space)
//                                 -> forward-WHT + per-token amax + INT3 quant
//                                 => rotated INT3 codes[D] + one fp16 scale.
//                                 (ChannelQuant CQ-3-rot, SYNTHESIZABLE, bit-exact
//                                 vs the behavioral reference — src/blocks/kve/rtl/tb_wht_pathb_syn.)
//   TIU   token_importance_unit  : H2O heavy-hitter scoring over L cache slots
//                                 -> per-slot keep-tier + an eviction victim slot.
//   ACU   precision_controller   : divide-free per-tile gate over the importance
//                                 distribution -> d_fp16 (peaked => keep fp16).
//
// One "compress step": host streams L value tokens (V) and their attention masses
// (W) in over SPI; the engine compresses every token, scores importance, picks an
// eviction victim, and decides the store precision; host reads back the compressed
// records (INT3 codes + fp16 scale per token), the reconstructed rotated V̂, the
// keep-tier bitmap, the eviction slot, and the precision bit. Everything fits the
// 20 workshop bidir pads by being streamed over a 4-wire SPI slave.
//
// SCOPE. This is the solidified KVE + TIU + precision-gate baseline. The Phase-2
// on-chip attention math (MatE fp16 P·V + inverse-WHT output) is retained but
// compiled out by default; define LAMBDA_PHASE2_MATE (and re-add mate_pv_fp16.sv
// + wht_inverse_out_syn.sv to the build) to bring the P·V/OUT datapath back.
//
// SIZES. D value channels/token, L cache slots. Defaults D=8, L=4 — the padring
// build instantiates it at D=2,L=2 (see chip_core.sv). D must be a power of two (WHT).

`default_nettype none

module lambda_kv_coproc #(
    parameter integer D          = 8,   // value channels per token (WHT dim; power of two)
    parameter integer L          = 4,   // cache slots / tokens per compress step
    parameter integer ADDR_WIDTH = 16
)(
    input  wire                 clk,
    input  wire                 rst_n,
    // serial host pads
    input  wire                 spi_sclk,
    input  wire                 spi_cs_n,
    input  wire                 spi_mosi,
    output wire                 spi_miso,
    // 4-bit debug/status observation (pin-frugal: one bidir pad each on the
    // shared reticle) = {gate_fp16, err, done, busy}
    output wire [3:0]           obs_out
);
    localparam integer IDXW = (D <= 1) ? 1 : $clog2(D);
    localparam integer SLW  = (L <= 1) ? 1 : $clog2(L);

    // ---------------- serial loader <-> byte fabric ------------------------
    wire [ADDR_WIDTH-1:0] bus_addr;
    wire [7:0]            bus_wdata;
    wire                  bus_we, bus_re;
    wire [7:0]            bus_rdata;
    wire                  start;
    wire [1:0]            precision_sel;

    reg  busy_r, done_r, err_r;
    reg  gate_fp16_r;
    wire [7:0] status_byte = {1'b0, err_r, gate_fp16_r, 3'b000, done_r, busy_r};

    spi_loader #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(8)) u_spi (
        .clk(clk), .rst_n(rst_n),
        .spi_sclk(spi_sclk), .spi_cs_n(spi_cs_n), .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_we(bus_we), .bus_re(bus_re),
        .bus_rdata(bus_rdata), .status_in(status_byte),
        .start(start), .precision_sel(precision_sel), .busy(busy_r), .done(done_r));

    // ---------------- address map (byte-addressed; fp16 little-endian) ------
    //   0x0300 WVEC  L    u8    per-token attention mass (TIU accumulate weight)
    //   0x0400 VVEC  L*D  fp16  value tokens (original space)   [host WRITE]
    //   0x0800 CODES L*D  int8  compressed rotated INT3 codes   [host READ]
    //   0x0A00 SCALE L    fp16  per-token fp16 scale            [host READ]
    //   0x0C00 VHAT  L*D  fp16  rotated fp16 reconstruction     [host READ]
    //   0x0002 DECI  1    u8    {gate_fp16, evict_slot, keep[..]} decision byte
    //   0x0001 STAT  1    u8    STATUS mirror
    // Phase-2 only (LAMBDA_PHASE2_MATE):
    //   0x0600 AVEC  L    fp16  per-token attention weight A[t] (P·V)  [host WRITE]
    //   0x1000 OUT   D    fp32  attention output o[d] = Σ_t A[t]·V̂[t][d]  [host READ]
    // (address map assumes L*D ≤ 256 so the V/A/CODES/SCALE/VHAT regions don't
    //  overlap; the workshop tile is D=2,L=2 — far inside that.)
    localparam [15:0] WBASE = 16'h0300;
    localparam [15:0] VBASE = 16'h0400;
    localparam [15:0] CBASE = 16'h0800;
    localparam [15:0] SBASE = 16'h0A00;
    localparam [15:0] HBASE = 16'h0C00;
`ifdef LAMBDA_PHASE2_MATE
    localparam [15:0] ABASE = 16'h0600;
    localparam [15:0] OBASE = 16'h1000;
`endif

    reg  [15:0]       v_buf   [0:L*D-1];   // fp16 value tokens (original space)
    reg  [7:0]        w_buf   [0:L-1];     // per-token importance mass
    reg  signed [7:0] code_buf[0:L*D-1];   // int3-in-int8 rotated codes
    reg  [15:0]       scale_buf[0:L-1];    // fp16 per-token scale
    reg  [15:0]       vhat_buf[0:L*D-1];   // fp16 rotated reconstruction
    reg  [SLW-1:0]    evict_slot_r;
    reg  [L-1:0]      keep_r;
`ifdef LAMBDA_PHASE2_MATE
    reg  [15:0]       a_buf   [0:L-1];     // fp16 per-token attention weight A[t] (P·V)
    reg  [31:0]       out_buf [0:D-1];     // fp32 attention output o[d] (host reads)
`endif

    // byte write decode
    wire in_w = (bus_addr >= WBASE) && (bus_addr < WBASE + L);
    wire in_v = (bus_addr >= VBASE) && (bus_addr < VBASE + 2*L*D);
    wire [ADDR_WIDTH-1:0] voff = bus_addr - VBASE;
`ifdef LAMBDA_PHASE2_MATE
    wire in_a = (bus_addr >= ABASE) && (bus_addr < ABASE + 2*L);
    wire [ADDR_WIDTH-1:0] aoff = bus_addr - ABASE;
`endif
    always_ff @(posedge clk) begin
        if (bus_we) begin
            if (in_w) w_buf[bus_addr - WBASE] <= bus_wdata;
            if (in_v) begin
                if (voff[0]) v_buf[voff>>1][15:8] <= bus_wdata;
                else         v_buf[voff>>1][7:0]  <= bus_wdata;
            end
`ifdef LAMBDA_PHASE2_MATE
            if (in_a) begin
                if (aoff[0]) a_buf[aoff>>1][15:8] <= bus_wdata;
                else         a_buf[aoff>>1][7:0]  <= bus_wdata;
            end
`endif
        end
    end

    // combinational host READ mux
    wire in_c = (bus_addr >= CBASE) && (bus_addr < CBASE + L*D);
    wire in_s = (bus_addr >= SBASE) && (bus_addr < SBASE + 2*L);
    wire in_h = (bus_addr >= HBASE) && (bus_addr < HBASE + 2*L*D);
    wire [ADDR_WIDTH-1:0] coff = bus_addr - CBASE;
    wire [ADDR_WIDTH-1:0] soff = bus_addr - SBASE;
    wire [ADDR_WIDTH-1:0] hoff = bus_addr - HBASE;
`ifdef LAMBDA_PHASE2_MATE
    wire in_o = (bus_addr >= OBASE) && (bus_addr < OBASE + 4*D);
    wire [ADDR_WIDTH-1:0] ooff = bus_addr - OBASE;
`endif
    wire [7:0] decision_byte = {gate_fp16_r, {(7-SLW){1'b0}}, evict_slot_r};
    reg  [7:0] rd_mux;
    always @* begin
        rd_mux = 8'h00;
        if (bus_addr == 16'h0001)      rd_mux = status_byte;
        else if (bus_addr == 16'h0002) rd_mux = decision_byte;
        else if (bus_addr == 16'h0003) rd_mux = (L >= 8) ? keep_r[7:0]
                                              : {{(8-L){1'b0}}, keep_r};  // keep bitmap
        else if (in_c) rd_mux = code_buf[coff][7:0];
        else if (in_s) rd_mux = soff[0] ? scale_buf[soff>>1][15:8] : scale_buf[soff>>1][7:0];
        else if (in_h) rd_mux = hoff[0] ? vhat_buf[hoff>>1][15:8] : vhat_buf[hoff>>1][7:0];
`ifdef LAMBDA_PHASE2_MATE
        else if (in_o) begin  // fp32 output, little-endian: 4 bytes/word
            case (ooff[1:0])
                2'd0: rd_mux = out_buf[ooff>>2][7:0];
                2'd1: rd_mux = out_buf[ooff>>2][15:8];
                2'd2: rd_mux = out_buf[ooff>>2][23:16];
                default: rd_mux = out_buf[ooff>>2][31:24];
            endcase
        end
`endif
    end
    assign bus_rdata = rd_mux;

    // ======================= MACRO INSTANTIATIONS ==========================

    // ---- KVE: CQ-3-rot value compressor (synthesizable) ----
    reg  [D*16-1:0] kve_in;
    wire [D*8-1:0]  kve_codes;
    wire [15:0]     kve_scale;
    wire [IDXW-1:0] kve_didx;
    wire [15:0]     kve_drot;
    reg  [15:0]     kt;   // current token index
    reg  [15:0]     ci;   // channel/stream index (drives kve_didx)
    integer pk;
    always @* begin
        kve_in = '0;
        for (pk = 0; pk < D; pk = pk + 1)
            kve_in[pk*16 +: 16] = v_buf[kt*D + pk];
    end
    assign kve_didx = ci[IDXW-1:0];
    cq_value_path_wht_syn #(.D(D), .DW(16)) u_kve (
        .in_vec(kve_in), .out_codes(kve_codes), .out_scale(kve_scale),
        .dec_codes(kve_codes), .dec_scale(kve_scale), .dec_idx(kve_didx),
        .dec_rot_f16(kve_drot));

    // ---- TIU: H2O token importance ----
    reg               tiu_av, tiu_lv, tiu_er;
    reg  [SLW-1:0]    tiu_as, tiu_ls;
    reg  [7:0]        tiu_aw;
    wire [7:0]        tiu_thr = 8'd48;
    wire              tiu_ev, tiu_busy;
    wire [SLW-1:0]    tiu_es;
    wire [L-1:0]      tiu_keep;
    token_importance_unit #(.N_SLOTS(L), .SCORE_WIDTH(8), .WEIGHT_WIDTH(8)) u_tiu (
        .clk(clk), .rst_n(rst_n),
        .acc_valid(tiu_av), .acc_slot(tiu_as), .acc_weight(tiu_aw),
        .ld_valid(tiu_lv), .ld_slot(tiu_ls),
        .evict_req(tiu_er), .evict_valid(tiu_ev), .evict_slot(tiu_es),
        .tier_threshold(tiu_thr), .tier_keep(tiu_keep), .busy(tiu_busy));

    // ---- ACU: precision gate over the importance distribution ----
    reg               acu_sv, acu_sl;
    reg  signed [7:0] acu_s;
    wire              acu_dv, acu_fp16;
    precision_controller #(.BLOCK_M(1), .BLOCK_N(L), .SCORE_WIDTH(8)) u_pc (
        .clk(clk), .rst_n(rst_n),
        .s_valid(acu_sv), .s_data(acu_s), .s_last(acu_sl),
        .d_valid(acu_dv), .d_fp16(acu_fp16));

`ifdef LAMBDA_PHASE2_MATE
    // ---- MatE: FP16 P·V (host-supplied A[t] × reconstructed V̂rot) ----
    // o_rot[d] = round_fp16( Σ_t A[t]·V̂rot[t][d] ), streamed one token/cycle;
    // c_valid pulses 2 cycles after s_last. A[t] = host attention weight a_buf.
    reg               pv16_sv, pv16_sl;
    reg  [15:0]       pv16_a;
    reg  [D*16-1:0]   pv16_v;
    wire              pv16_cv;
    wire [D*16-1:0]   pv16_c;
    mate_pv_fp16 #(.N(D)) u_pv16 (
        .clk(clk), .rst_n(rst_n),
        .s_valid(pv16_sv), .a_data(pv16_a), .v_data(pv16_v), .s_last(pv16_sl),
        .c_valid(pv16_cv), .c_data(pv16_c));

    // ---- KVE: inverse WHT on the P·V output (rotation undone once) ----
    // o[d] = InvWHT(o_rot)[d] (fp32). Combinational; latched into out_buf.
    reg  [D*16-1:0] inv_rot_in;
    wire [D*32-1:0] inv_vhat;
    wht_inverse_out_syn #(.D(D), .DW(16)) u_inv (
        .rot_out (inv_rot_in),
        .vhat_out(inv_vhat));
`endif

    // ======================= COMPRESS-STEP FSM =============================
    localparam [3:0]
        S_IDLE    = 4'd0,
        S_KVE     = 4'd1,   // per token: sweep D channels -> codes + scale + vhat
        S_PV      = 4'd8,   // stream L tokens (A[t] × V̂rot) through the fp16 P·V
        S_PV_W    = 4'd9,   // wait P·V result (2 cyc after s_last)
        S_INV     = 4'd10,  // inverse-WHT (combinational) -> latch out_buf
        S_TIU_LD  = 4'd2,
        S_TIU_ACC = 4'd3,
        S_TIU_EV  = 4'd4,
        S_PC      = 4'd5,
        S_PC_W    = 4'd6,
        S_DONE    = 4'd7;

    reg [3:0]  state;
    reg [15:0] tout;
    integer    gp;   // P·V / inverse-WHT channel loop index (clocked block)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; ci <= 0; kt <= 0; tout <= 0;
            busy_r <= 0; done_r <= 0; err_r <= 0; gate_fp16_r <= 0;
            tiu_av <= 0; tiu_lv <= 0; tiu_er <= 0; tiu_as <= 0; tiu_ls <= 0; tiu_aw <= 0;
            acu_sv <= 0; acu_sl <= 0; acu_s <= 0;
            evict_slot_r <= 0; keep_r <= 0;
`ifdef LAMBDA_PHASE2_MATE
            pv16_sv <= 0; pv16_sl <= 0;
`endif
        end else begin
            tiu_av <= 0; tiu_lv <= 0; tiu_er <= 0;
            acu_sv <= 0; acu_sl <= 0;
`ifdef LAMBDA_PHASE2_MATE
            pv16_sv <= 0; pv16_sl <= 0;
`endif
            case (state)
            S_IDLE: begin
                busy_r <= 0;
                if (start) begin
                    busy_r <= 1; err_r <= 0; done_r <= 0;
                    kt <= 0; ci <= 0; state <= S_KVE;
                end
            end
            // KVE: compress each token; scale is per-token (capture at ci==0),
            // codes + rotated reconstruction are per-channel.
            S_KVE: begin
                code_buf[kt*D + ci] <= $signed(kve_codes[ci*8 +: 8]);
                vhat_buf[kt*D + ci] <= kve_drot;
                if (ci == 0) scale_buf[kt] <= kve_scale;
                if (ci == D-1) begin
                    ci <= 0;
                    if (kt == L-1) begin
                        kt <= 0;
`ifdef LAMBDA_PHASE2_MATE
                        state <= S_PV;
`else
                        state <= S_TIU_LD;
`endif
                    end
                    else kt <= kt + 1;
                end else ci <= ci + 1;
            end
`ifdef LAMBDA_PHASE2_MATE
            // P·V: stream A[t] × V̂rot[t] into the fp16 MAC (one token/cycle).
            S_PV: begin
                pv16_sv <= 1'b1;
                pv16_a  <= a_buf[ci];
                pv16_sl <= (ci == L-1);
                for (gp = 0; gp < D; gp = gp + 1)
                    pv16_v[gp*16 +: 16] <= vhat_buf[ci*D + gp];
                if (ci == L-1) begin ci <= 0; tout <= 0; state <= S_PV_W; end
                else ci <= ci + 1;
            end
            // wait for the P·V row sum (c_valid pulses 2 cyc after s_last).
            S_PV_W: begin
                tout <= tout + 1;
                if (pv16_cv) begin
                    for (gp = 0; gp < D; gp = gp + 1)
                        inv_rot_in[gp*16 +: 16] <= pv16_c[gp*16 +: 16];
                    state <= S_INV;
                end else if (tout > 16) begin err_r <= 1'b1; state <= S_DONE; end
            end
            // inverse-WHT (combinational) -> latch the fp32 attention output.
            S_INV: begin
                for (gp = 0; gp < D; gp = gp + 1)
                    out_buf[gp] <= inv_vhat[gp*32 +: 32];
                state <= S_TIU_LD;
            end
`endif
            // TIU: install L slots
            S_TIU_LD: begin
                tiu_lv <= 1'b1; tiu_ls <= ci[SLW-1:0];
                if (ci == L-1) begin ci <= 0; state <= S_TIU_ACC; end
                else ci <= ci + 1;
            end
            // TIU: accumulate per-token attention mass
            S_TIU_ACC: begin
                tiu_av <= 1'b1; tiu_as <= ci[SLW-1:0]; tiu_aw <= w_buf[ci];
                if (ci == L-1) begin ci <= 0; tout <= 0; state <= S_TIU_EV; end
                else ci <= ci + 1;
            end
            // TIU: request eviction victim + latch keep tier
            S_TIU_EV: begin
                tout <= tout + 1;
                if (tout == 0) tiu_er <= 1'b1;
                keep_r <= tiu_keep;
                if (tiu_ev) begin evict_slot_r <= tiu_es; ci <= 0; state <= S_PC; end
                else if (tout > (L + 16)) begin evict_slot_r <= tiu_es; ci <= 0; state <= S_PC; end
            end
            // ACU: stream the importance masses as the precision-gate score tile
            S_PC: begin
                acu_sv <= 1'b1;
                acu_s  <= $signed({1'b0, w_buf[ci][6:0]});  // mass as a non-negative score
                acu_sl <= (ci == L-1);
                if (ci == L-1) begin ci <= 0; tout <= 0; state <= S_PC_W; end
                else ci <= ci + 1;
            end
            S_PC_W: begin
                tout <= tout + 1;
                if (acu_dv) begin gate_fp16_r <= acu_fp16; state <= S_DONE; end
                else if (tout > 32) begin err_r <= 1'b1; state <= S_DONE; end
            end
            S_DONE: begin busy_r <= 0; done_r <= 1; state <= S_IDLE; end
            default: state <= S_IDLE;
            endcase
        end
    end

    // ---------------- observation outputs (4-bit status) -------------------
    // {gate_fp16, err, done, busy} — one shared-reticle bidir pad each.
    assign obs_out = {gate_fp16_r, err_r, done_r, busy_r};

    // keep debug taps from being pruned
    logic _unused;
    assign _unused = &{1'b0, precision_sel, keep_r, tiu_busy, bus_re, in_c, in_s, in_h};

endmodule

`default_nettype wire
