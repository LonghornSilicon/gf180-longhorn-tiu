// coproc_top.sv — integration top for hardening the KVE+TIU coprocessor into the
// Chipathon-provided padframe DEF (via FP_DEF_TEMPLATE).
//
// The org generates the padframe from info.yaml and returns a DEF whose PINS are
// named after our info.yaml entries. LibreLane maps top-level ports to those DEF
// pins BY NAME, so this wrapper exposes SCALAR ports matching info.yaml exactly
// (clk, rst_n, spi_sclk/cs_n/mosi, spi_miso, obs0..obs3) and fans the coprocessor's
// obs_out[3:0] status bus out to the four scalar obs pins.
//
// >>> DEF-DAY TODO (verify against the actual DEF before hardening): <<<
//   1. Confirm these port names EXACTLY match the DEF pin names (case-sensitive).
//   2. If the DEF names the status pins as a bus (obs_out[3:0]) instead of obs0..3,
//      or power as VDD/VSS instead of vdd/vss, adjust the ports here to match.
//   3. Confirm obs bit order: obs_out = {gate_fp16, err, done, busy}
//      -> obs0=busy, obs1=done, obs2=err, obs3=gate_fp16 (matches info.yaml).

`default_nettype none

module coproc_top (
`ifdef USE_POWER_PINS
    inout  wire vdd,
    inout  wire vss,
`endif
    input  wire clk,
    input  wire rst_n,
    // 4-wire SPI slave
    input  wire spi_sclk,
    input  wire spi_cs_n,
    input  wire spi_mosi,
    output wire spi_miso,
    // 4-bit status observation
    output wire obs0,      // busy
    output wire obs1,      // done
    output wire obs2,      // err
    output wire obs3       // gate_fp16
);
    wire [3:0] obs;
    assign obs0 = obs[0];
    assign obs1 = obs[1];
    assign obs2 = obs[2];
    assign obs3 = obs[3];

    lambda_kv_coproc #(.D(2), .L(2), .ADDR_WIDTH(16)) u_coproc (
        .clk      (clk),
        .rst_n    (rst_n),
        .spi_sclk (spi_sclk),
        .spi_cs_n (spi_cs_n),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .obs_out  (obs)      // {gate_fp16, err, done, busy}
    );
endmodule

`default_nettype wire
