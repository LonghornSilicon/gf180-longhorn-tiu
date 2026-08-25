// coproc_top.sv — integration top for hardening the KVE+TIU coprocessor into the
// Chipathon-provided padframe DEF (via FP_DEF_TEMPLATE).
//
// The org generates the padframe from info.yaml and returns a DEF whose PINS are
// named after our info.yaml entries. LibreLane maps top-level ports to those DEF
// pins BY NAME, so this wrapper exposes SCALAR ports matching info.yaml exactly
// (clk, rst_n, spi_sclk/cs_n/mosi, spi_miso, obs0..obs3, VDD/VSS) and wires them
// straight to lambda_kv_coproc, which now exposes scalar obs0..obs3 directly.
//
// >>> DEF-DAY TODO (verify against the actual DEF before hardening): <<<
//   1. Confirm these port names EXACTLY match the DEF pin names (case-sensitive).
//   2. Ports are scalar obs0..obs3 and power VDD/VSS (uppercase) to match
//      info.yaml + the hardened core; re-check if the delivered DEF differs.
//   3. Confirm obs bit order: obs0=busy, obs1=done, obs2=err, obs3=gate_fp16
//      (matches info.yaml and lambda_kv_coproc).

`default_nettype none

module coproc_top (
`ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
`endif
    input  wire clk,
    input  wire rst_n,
    // 4-wire SPI slave
    input  wire spi_sclk,
    input  wire spi_cs_n,
    input  wire spi_mosi,
    output wire spi_miso,
    // 4-bit status observation (scalar pins matching info.yaml by name)
    output wire obs0,      // busy
    output wire obs1,      // done
    output wire obs2,      // err
    output wire obs3       // gate_fp16
);
    // lambda_kv_coproc now exposes scalar obs0..obs3 directly (obs0=busy,
    // obs1=done, obs2=err, obs3=gate_fp16), so wire them straight through.
    lambda_kv_coproc #(.D(2), .L(2), .ADDR_WIDTH(16)) u_coproc (
        .clk      (clk),
        .rst_n    (rst_n),
        .spi_sclk (spi_sclk),
        .spi_cs_n (spi_cs_n),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .obs0     (obs0),
        .obs1     (obs1),
        .obs2     (obs2),
        .obs3     (obs3)
    );
endmodule

`default_nettype wire
