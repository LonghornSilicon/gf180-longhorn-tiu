// SPDX-License-Identifier: Apache-2.0
//
// Longhorn TIU (H2O heavy-hitter KV-cache eviction core) on GF180MCU.
// chip_core wires the token_importance_unit (N_SLOTS=4) to the slot pads.
//
//   input_in[1:0]  = op    00=NOP 01=ACC 10=LOAD 11=EVICT
//   input_in[3:2]  = slot   target slot 0..3 (ACC / LOAD)
//   bidir[7:0]     = weight  ACC attention-mass increment (pads are INPUTS here)
//   bidir[15:8]    = { occupancy[3:0], busy, evict_valid, evict_slot[1:0] } (OUTPUTS)
//   bidir[N-1:16]  = unused (inputs, tied)

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS
    )(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input  wire clk,
    input  wire rst_n,

    input  wire [NUM_INPUT_PADS-1:0] input_in,
    output wire [NUM_INPUT_PADS-1:0] input_pu,
    output wire [NUM_INPUT_PADS-1:0] input_pd,

    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,

    inout  wire [NUM_ANALOG_PADS-1:0] analog
);

    localparam int unsigned N_SLOTS = 4;

    // --- input pads: no pulls ---
    assign input_pu = '0;
    assign input_pd = '0;

    wire [1:0] op     = input_in[1:0];
    wire [1:0] slot   = input_in[3:2];
    wire [7:0] weight = bidir_in[7:0];

    wire acc_valid = (op == 2'b01);
    wire ld_valid  = (op == 2'b10);
    wire evict_req = (op == 2'b11);

    wire               evict_valid;
    wire [1:0]         evict_slot;
    wire [N_SLOTS-1:0] tier_keep;
    wire               busy;

    token_importance_unit #(
        .N_SLOTS(N_SLOTS), .SCORE_WIDTH(8), .WEIGHT_WIDTH(8)
    ) u_tiu (
        .clk(clk), .rst_n(rst_n),
        .acc_valid(acc_valid), .acc_slot(slot), .acc_weight(weight),
        .ld_valid(ld_valid),   .ld_slot(slot),
        .evict_req(evict_req), .evict_valid(evict_valid), .evict_slot(evict_slot),
        .tier_threshold(8'd0), .tier_keep(tier_keep), .busy(busy)
    );

    wire [7:0] result = {tier_keep[3:0], busy, evict_valid, evict_slot};

    // --- bidir directions: [7:0]=inputs (weight), [15:8]=outputs (result), rest=inputs ---
    assign bidir_oe  = { {(NUM_BIDIR_PADS-16){1'b0}}, 8'hFF, 8'h00 };
    assign bidir_out = { {(NUM_BIDIR_PADS-16){1'b0}}, result, 8'h00 };

    assign bidir_cs = '0;
    assign bidir_sl = '0;
    assign bidir_ie = ~bidir_oe;      // input buffer enabled where not driving
    assign bidir_pu = '0;
    assign bidir_pd = '0;

    // tie off unused bits so lint/synth is clean
    wire _unused = &{ bidir_in[NUM_BIDIR_PADS-1:8], analog, 1'b0 };

endmodule

`default_nettype wire
