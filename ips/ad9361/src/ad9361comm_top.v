// ***************************************************************************
// ***************************************************************************
//
// ***************************************************************************
// ***************************************************************************
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module ad9361comm_top (

  gpio_io_i,
  gpio_io_o,
  gpio_io_t,

  sck_i,
  sck_o,
  ss_i,
  ss_o,
  io1_i,
  io0_i,
  io0_o,

  gpio_resetb,
  gpio_sync,
  gpio_en_agc,
  gpio_ctl,
  gpio_status,

  spi_csn_0,
  spi_clk,
  spi_mosi,
  spi_miso
 );

//block inputs
output  [14:0]  gpio_io_i;
input   [14:0]  gpio_io_o;
input   [14:0]  gpio_io_t;

output   sck_i;
input    sck_o;
output  [7:0]   ss_i;
input   [7:0]   ss_o;
//output   ss_i;
//input    ss_o;
output   io1_i;
output   io0_i;
input    io0_o;

//block outputs
inout           gpio_resetb;
inout           gpio_sync;
inout           gpio_en_agc;
inout   [ 3:0]  gpio_ctl;
inout   [ 7:0]  gpio_status;

output          spi_csn_0;
output          spi_clk;
output          spi_mosi;
input           spi_miso;

   // internal signals

wire    [63:0]  gpio_i;
wire    [63:0]  gpio_o;
wire    [63:0]  gpio_t;
wire    [ 7:0]  spi_csn;
wire            spi_clk;
wire            spi_mosi;
wire            spi_miso;

// default logic
assign spi_csn_0 = spi_csn[0];

//drive ports

assign gpio_o[14:0] = gpio_io_o[14:0];
assign gpio_t[14:0] = gpio_io_t[14:0];
assign gpio_i[14:0] = gpio_io_i[14:0];


assign spi_clk = sck_i;
assign spi_clk = sck_o;
assign spi_csn[7:0] = ss_i[7:0];
assign spi_csn[7:0] = ss_o[7:0];
assign spi_miso = io1_i;
assign spi_mosi = io0_i;
assign spi_mosi = io0_o;

// instantiations

ad_iobuf #(.DATA_WIDTH(15)) i_iobuf (
    .dio_t (gpio_t[14:0]),
    .dio_i (gpio_o[14:0]),
    .dio_o (gpio_i[14:0]),
    .dio_p ({ gpio_resetb,
              gpio_sync,
              gpio_en_agc,
              gpio_ctl,
              gpio_status}));

endmodule
// ***************************************************************************
// ***************************************************************************
