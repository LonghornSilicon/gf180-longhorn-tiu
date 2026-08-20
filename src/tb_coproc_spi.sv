// tb_coproc_spi.sv — self-checking SPI functional test for the solidified
// KVE + TIU + precision-gate coprocessor (scope B, LAMBDA_PHASE2_MATE off).
//
// Proves the "stream everything over the 4-wire SPI link" contract end to end:
//   host writes W (importance masses) + V (fp16 values) over SPI ->
//   CMD_START -> poll STATUS busy/done over SPI -> read back the decision byte
//   (evict slot + gate), the keep bitmap, and the KVE CODES/SCALE over SPI.
//
// Checks (deterministic, no fp16 golden needed):
//   * FSM completes: STATUS.done asserts, STATUS.err stays 0.
//   * TIU evict slot  == argmin(mass)              (masses 10 < 60 -> slot 0)
//   * TIU keep bitmap == (mass >= 48) per slot     ([10,60] -> 0b10)
//   * ACU gate         == 0                          (max*N > 10*sum never fires at L=2)
//   * KVE codes are in the INT3 range [-4,3] and readback is stable.
// (KVE bit-exactness vs the behavioral reference is covered by the block-level
//  tb_cq_syn / tb_wht_pathb_syn in the monorepo; here we prove the SPI path.)
//
// Run: iverilog -g2012 -s tb_coproc_spi -o /tmp/tb tb_coproc_spi.sv \
//        lambda_kv_coproc.sv spi_loader.sv cq_value_path_wht_syn.sv \
//        wht_unit_syn.sv fp16_addsub_syn.sv cq_units_syn.sv \
//        token_importance_unit.sv precision_controller.sv && vvp /tmp/tb

`timescale 1ns/1ps
`default_nettype none

module tb_coproc_spi;
    localparam integer D = 2;
    localparam integer L = 2;

    // SPI CMDs / address map (mirror of the RTL)
    localparam [7:0] CMD_WRITE = 8'h01, CMD_READ = 8'h02, CMD_START = 8'h03;
    localparam [15:0] WBASE = 16'h0300, VBASE = 16'h0400,
                      CBASE = 16'h0800, SBASE = 16'h0A00, HBASE = 16'h0C00;
    localparam [15:0] STAT_ADDR = 16'h0001, DECI_ADDR = 16'h0002, KEEP_ADDR = 16'h0003;
    localparam [7:0] TIER_THR = 8'd48;

    // Half-bit width in core clocks (SPI SCLK is oversampled in the core domain;
    // must be >> the 3-flop sync depth). 4 core clocks/phase is comfortable.
    localparam integer TQ = 4;

    reg clk = 1'b0, rst_n = 1'b0;
    always #5 clk = ~clk;      // 100 MHz core clock

    // SPI host lines
    reg  spi_sclk = 1'b0, spi_cs_n = 1'b1, spi_mosi = 1'b0;
    wire spi_miso;
    wire [3:0] obs_out;

    lambda_kv_coproc #(.D(D), .L(L), .ADDR_WIDTH(16)) dut (
        .clk(clk), .rst_n(rst_n),
        .spi_sclk(spi_sclk), .spi_cs_n(spi_cs_n), .spi_mosi(spi_mosi),
        .spi_miso(spi_miso), .obs_out(obs_out));

    integer errors = 0;

    task automatic wclk(input integer n); begin repeat (n) @(posedge clk); end endtask

    // Shift one byte out on MOSI (MSB first) and simultaneously sample MISO.
    task automatic spi_xfer_byte(input [7:0] tx, output [7:0] rx);
        integer i;
        begin
            rx = 8'h00;
            for (i = 7; i >= 0; i = i - 1) begin
                spi_mosi = tx[i];       // change while SCLK low (CPHA=0)
                wclk(TQ);
                spi_sclk = 1'b1;        // rising edge: slave samples MOSI
                wclk(1);                // sample MISO early, before bit_cnt advances
                rx[i] = spi_miso;
                wclk(TQ-1);
                spi_sclk = 1'b0;
            end
        end
    endtask

    // A full SPI frame: CS low, send cmd/addr/data, CS high. `nread` MISO bytes
    // captured into rdata (valid for CMD_READ during the data phase).
    task automatic spi_write(input [15:0] addr, input integer n, input [8*32-1:0] data);
        integer j; reg [7:0] dummy;
        begin
            spi_cs_n = 1'b0; wclk(TQ);
            spi_xfer_byte(CMD_WRITE, dummy);
            spi_xfer_byte(addr[15:8], dummy);
            spi_xfer_byte(addr[7:0],  dummy);
            for (j = 0; j < n; j = j + 1)
                spi_xfer_byte(data[8*j +: 8], dummy);
            wclk(TQ); spi_cs_n = 1'b1; wclk(TQ*2);
        end
    endtask

    task automatic spi_read(input [15:0] addr, input integer n, output [8*32-1:0] rdata);
        integer j; reg [7:0] rb;
        begin
            rdata = '0;
            spi_cs_n = 1'b0; wclk(TQ);
            spi_xfer_byte(CMD_READ, rb);
            spi_xfer_byte(addr[15:8], rb);
            spi_xfer_byte(addr[7:0],  rb);
            for (j = 0; j < n; j = j + 1) begin
                spi_xfer_byte(8'h00, rb);   // dummy tx; capture MISO
                rdata[8*j +: 8] = rb;
            end
            wclk(TQ); spi_cs_n = 1'b1; wclk(TQ*2);
        end
    endtask

    task automatic spi_start;
        reg [7:0] dummy;
        begin
            spi_cs_n = 1'b0; wclk(TQ);
            spi_xfer_byte(CMD_START, dummy);
            wclk(TQ); spi_cs_n = 1'b1; wclk(TQ*2);
        end
    endtask

    task automatic check(input cond, input [8*48-1:0] name);
        begin
            if (cond) $display("  PASS  %0s", name);
            else      begin $display("  FAIL  %0s", name); errors = errors + 1; end
        end
    endtask

    // fp16 helpers for the input values (bit patterns; exact value irrelevant to
    // the deterministic checks — KVE just needs real, non-trivial operands).
    localparam [15:0] FP16_1_0 = 16'h3C00, FP16_2_0 = 16'h4000,
                      FP16_0_5 = 16'h3800, FP16_M3  = 16'hC200; // -3.0

    reg [8*32-1:0] wbuf, vbuf, rd;
    reg [7:0] status, decision, keepb, codeb;
    integer timeout;

    initial begin
        // ---- reset ----
        rst_n = 1'b0; wclk(20); rst_n = 1'b1; wclk(20);

        // ---- write importance masses W = [10, 60] (u8, one byte per slot) ----
        wbuf = '0; wbuf[7:0] = 8'd10; wbuf[15:8] = 8'd60;
        spi_write(WBASE, L, wbuf);

        // ---- write value tokens V (fp16 LE): token0=[1.0,2.0], token1=[0.5,-3.0] ----
        vbuf = '0;
        vbuf[15:0]  = FP16_1_0; vbuf[31:16] = FP16_2_0;   // token 0, D=2 channels
        vbuf[47:32] = FP16_0_5; vbuf[63:48] = FP16_M3;    // token 1
        spi_write(VBASE, 2*L*D, vbuf);

        // ---- kick one compress step ----
        spi_start();

        // ---- poll STATUS until done (bit1), bounded ----
        status = 8'h00; timeout = 0;
        while (!status[1] && timeout < 2000) begin
            spi_read(STAT_ADDR, 1, rd); status = rd[7:0];
            timeout = timeout + 1;
        end
        check(status[1] === 1'b1, "STATUS.done asserted");
        check(status[6] !== 1'b1, "STATUS.err clear");

        // ---- decision byte: bit7=gate_fp16, bits[SLW-1:0]=evict_slot ----
        spi_read(DECI_ADDR, 1, rd); decision = rd[7:0];
        check(decision[0] === 1'b0, "TIU evict slot == 0 (argmin mass)");
        check(decision[7] === 1'b0, "ACU gate fp16 == 0 (L=2 never peaky)");

        // ---- keep bitmap at 0x0003: [10>=48 ->0, 60>=48 ->1] = 0b10 ----
        spi_read(KEEP_ADDR, 1, rd); keepb = rd[7:0];
        check(keepb[1:0] === 2'b10, "TIU keep bitmap == 0b10");

        // ---- KVE codes: read L*D = 4 int3-in-int8 codes, check range [-4,3] ----
        spi_read(CBASE, L*D, rd);
        begin : code_check
            integer k; reg ok; reg signed [7:0] cc;
            ok = 1'b1;
            for (k = 0; k < L*D; k = k + 1) begin
                cc = rd[8*k +: 8];
                if (cc < -4 || cc > 3) ok = 1'b0;
            end
            check(ok, "KVE codes within INT3 range [-4,3]");
        end

        // ---- SCALE readback stable across two reads ----
        begin : scale_check
            reg [8*32-1:0] s1, s2;
            spi_read(SBASE, 2*L, s1);
            spi_read(SBASE, 2*L, s2);
            check(s1[8*2*L-1:0] === s2[8*2*L-1:0], "KVE scale readback stable");
        end

        $display("");
        if (errors == 0) $display("COPROC SPI FUNCTIONAL TEST: ALL CHECKS PASS");
        else             $display("COPROC SPI FUNCTIONAL TEST: %0d CHECK(S) FAILED", errors);
        $finish;
    end

    // global watchdog
    initial begin #5_000_000; $display("TB WATCHDOG TIMEOUT"); $finish; end

endmodule

`default_nettype wire
