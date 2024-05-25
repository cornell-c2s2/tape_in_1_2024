//========================================================================
// loopback_inXbar_msgs0
//========================================================================

`default_nettype none

//------------------------------------------------------------------------
// VTB Helper Macros
//------------------------------------------------------------------------

`define VTB_INPUT_DELAY 1
`define VTB_OUTPUT_ASSERT_DELAY 3

// CYCLE_TIME and INTRA_CYCLE_TIME are duration of time.
`define CYCLE_TIME 25
`define INTRA_CYCLE_TIME (`VTB_OUTPUT_ASSERT_DELAY-`VTB_INPUT_DELAY)

`timescale 1ns / 1ns

`define T(a0, a1, a2, a3, a4, a5, a6, a7) \
        t(a0,a1,a2,a3,a4,a5,a6,a7,`__LINE__)

// Tick one extra cycle upon an error.
`define VTB_TEST_FAIL(lineno, out, ref, port_name) \
        $display("- Timestamp      : %0d (default unit: ns)", $time); \
        $display("- Cycle number   : %0d (variable: cycle_count)", cycle_count); \
        $display("- line number    : line %0d in loopback_inXbar_msgs0_tb.v.cases", lineno); \
        $display("- port name      : %s", port_name); \
        $display("- expected value : 0x%x", ref); \
        $display("- actual value   : 0x%x", out); \
        $display(""); \
        #(`CYCLE_TIME-`INTRA_CYCLE_TIME); \
        cycle_count += 1; \
        #`CYCLE_TIME; \
        cycle_count += 1; \
        $fatal;

`define CHECK(lineno, out, ref, port_name) \
      if ((|(out ^ out)) == 1'b0) ; \
      else begin \
        $display(""); \
        $display("The test bench received a value containing X/Z's! Please note"); \
        $display("that the VTB is pessmistic about X's and you should make sure"); \
        $display("all output ports of your DUT does not produce X's after reset."); \
        `VTB_TEST_FAIL(lineno, out, ref, port_name) \
      end \
      if (out != ref) begin \
        $display(""); \
        $display("The test bench received an incorrect value!"); \
        `VTB_TEST_FAIL(lineno, out, ref, port_name) \
      end

//========================================================================
// Top-Level Test Harness
//========================================================================

module loopback_inXbar_msgs0_tb;

  //----------------------------------------------------------------------
  // Create clocks
  //----------------------------------------------------------------------

  // Clock for Caravel

  reg clock = 1'b0;
  always #12.5 clock = ~clock;

  //----------------------------------------------------------------------
  // Instantiate Caravel and SPI Flash
  //----------------------------------------------------------------------

  wire        VDD3V3;
  wire        VDD1V8;
  wire        VSS;
  reg         RSTB;
  reg         CSB;

  wire        gpio;
  wire [37:0] mprj_io;

  wire        flash_csb;
  wire        flash_clk;
  wire        flash_io0;
  wire        flash_io1;

  caravel uut (
      .vddio    (VDD3V3),
      .vddio_2  (VDD3V3),
      .vssio    (VSS),
      .vssio_2  (VSS),
      .vdda     (VDD3V3),
      .vssa     (VSS),
      .vccd     (VDD1V8),
      .vssd     (VSS),
      .vdda1    (VDD3V3),
      .vdda1_2  (VDD3V3),
      .vdda2    (VDD3V3),
      .vssa1    (VSS),
      .vssa1_2  (VSS),
      .vssa2    (VSS),
      .vccd1    (VDD1V8),
      .vccd2    (VDD1V8),
      .vssd1    (VSS),
      .vssd2    (VSS),
      .clock    (clock),
      .gpio     (gpio),
      .mprj_io  (mprj_io),
      .flash_csb(flash_csb),
      .flash_clk(flash_clk),
      .flash_io0(flash_io0),
      .flash_io1(flash_io1),
      .resetb   (RSTB)
  );

  spiflash #(
      .FILENAME("loopback_inXbar_msgs0.hex")
  ) spiflash (
      .csb(flash_csb),
      .clk(flash_clk),
      .io0(flash_io0),
      .io1(flash_io1),
      .io2(),
      .io3()
  );

  //----------------------------------------------------------------------
  // Rename the mprj_io
  //----------------------------------------------------------------------

  // Inputs

  wire adapter_parity;
  logic [0:0] cs;
  logic [22:0] io_oeb;
  logic [4:0] io_out;
  wire minion_parity;
  wire miso;
  logic [0:0] mosi;
  logic [0:0] sclk;

  wire [3:0] checkbits;

  assign mprj_io[7]     = cs;
  assign mprj_io[8]     = mosi;
  assign mprj_io[9]     = sclk;

  assign adapter_parity = mprj_io[5];
  assign minion_parity  = mprj_io[6];
  assign miso           = mprj_io[10];

  assign checkbits      = mprj_io[31:28];

  //----------------------------------------------------------------------
  // Power-up and reset sequence
  //----------------------------------------------------------------------

  initial begin
    RSTB <= 1'b0;
    CSB  <= 1'b1;  // Force CSB high
    #2000;
    RSTB <= 1'b1;  // Release reset
    #300000;
    CSB = 1'b0;  // CSB can be released
  end

  reg power1;
  reg power2;
  reg power3;
  reg power4;

  initial begin
    power1 <= 1'b0;
    power2 <= 1'b0;
    power3 <= 1'b0;
    power4 <= 1'b0;
    #100;
    power1 <= 1'b1;
    #100;
    power2 <= 1'b1;
    #100;
    power3 <= 1'b1;
    #100;
    power4 <= 1'b1;
  end

  assign VDD3V3 = power1;
  assign VDD1V8 = power2;
  assign VSS    = 1'b0;

  //----------------------------------------------------------------------
  // Setup VCD dumping and overall timeout
  //----------------------------------------------------------------------

  initial begin
    $dumpfile("loopback_inXbar_msgs0.vcd");
    $dumpvars(0, loopback_inXbar_msgs0_tb);
    #1;

    // Repeat cycles of 1000 clock edges as needed to complete testbench
    repeat (75) begin
      repeat (1000) @(posedge clock);
    end
    $display("%c[1;31m", 27);
`ifdef GL
    $display("Monitor: Timeout GL Failed");
`else
    $display("Monitor: Timeout RTL Failed");
`endif
    $display("%c[0m", 27);
    $finish;
  end

  //----------------------------------------------------------------------
  // VTB task for assigning inputs and checking outputs
  //----------------------------------------------------------------------

  integer cycle_count;

  task t(input logic [0:0] ref_adapter_parity, input logic [0:0] inp_cs,
         input logic [22:0] ref_io_oeb, input logic [4:0] ref_io_out,
         input logic [0:0] ref_minion_parity, input logic [0:0] ref_miso,
         input logic [0:0] inp_mosi, input logic [0:0] inp_sclk, input integer lineno);
    begin
      cs   = inp_cs;
      mosi = inp_mosi;
      sclk = inp_sclk;
      #`INTRA_CYCLE_TIME;
      `CHECK(lineno, adapter_parity, ref_adapter_parity,
             "adapter_parity (adapter_parity in Verilog)");
      `CHECK(lineno, minion_parity, ref_minion_parity, "minion_parity (minion_parity in Verilog)");
      `CHECK(lineno, miso, ref_miso, "miso (miso in Verilog)");
      //$display(" miso: %0d | ref_miso: %0d", miso, ref_miso);
      #(`CYCLE_TIME - `INTRA_CYCLE_TIME);
      cycle_count += 1;
    end
  endtask

  //----------------------------------------------------------------------
  // Execute the generated VTB cases
  //----------------------------------------------------------------------

  initial begin

    // This is how we wait for the firmware to configure the IO ports
    wait (checkbits == 4'hA);

    wait (clock == 1);
    wait (clock == 0);
    cycle_count = 0;

    #(`CYCLE_TIME / 2);

    #`VTB_INPUT_DELAY;
    #`CYCLE_TIME;
    cycle_count = 1;
    #`CYCLE_TIME;
    cycle_count = 2;
    // 2 cycles plus input delay

    // Start test
    `include "loopback_inXbar_msgs0_tb.v.cases"

    $display("");
    $display("  [ passed ]");
    $display("");

    // Tick one extra cycle for better waveform
    #`CYCLE_TIME;
    cycle_count += 1;
    $finish;

  end

endmodule

`default_nettype wire
