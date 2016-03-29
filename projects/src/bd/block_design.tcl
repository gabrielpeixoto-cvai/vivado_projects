# November 12, 2015 - Igor F.
#
# TCL Script for assembling the block design for VC707
#
# 	Global parameters from the main build script (build.tcl) are used to configure the
# block design.

######################################################################
# Process parameters
#
######################################################################

# Compute number of interrupts
set fixed_interrupts 3

set no_interrupts $fixed_interrupts

######################################################################
#
# Instantiations and corresponding board connections
#
######################################################################

# Microblaze
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:9.5 microblaze_0

# DDR3 Memory (Memory Interface Generator from the "Board Parts" panel)
create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:2.3 mig_7series_0
apply_board_connection -board_interface "ddr3_sdram" -ip_intf "mig_7series_0/mig_ddr_interface" -diagram "block_design"

# AXI Uartlite
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0
apply_board_connection -board_interface "rs232_uart" -ip_intf "axi_uartlite_0/UART" -diagram "block_design"

# AXI Timer
#create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:2.0 axi_timer_0

if {$::board == "VC707"} {
	# AXI Ethernet
	create_bd_cell -type ip -vlnv xilinx.com:ip:axi_ethernet:7.0 axi_ethernet_0
	# Connect the MAC to the PHY via the Serial-gigabit media-independent Interface (SGMII):
	apply_board_connection -board_interface "sgmii" -ip_intf "axi_ethernet_0/sgmii" -diagram "block_design"
	# Connect the PHY to the MDIO interface, through which its registers are managed
	apply_board_connection -board_interface "mdio_mdc" -ip_intf "axi_ethernet_0/mdio" -diagram "block_design"
	apply_board_connection -board_interface "phy_reset_out" -ip_intf "axi_ethernet_0/phy_rst_n" -diagram "block_design"
	apply_board_connection -board_interface "sgmii_mgt_clk" -ip_intf "axi_ethernet_0/mgt_clk" -diagram "block_design"
} elseif {$::board == "VC709"} {


}

######################################################################
#
# Block automations and configurations
#
######################################################################

# DDR3
# Step 1) Save a predefined .prj configuration file
source $origin_dir/src/bd/config_files/mig_7series_clk0_200.tcl
# Step 2) Apply block automation
apply_bd_automation -rule xilinx.com:bd_rule:mig_7series -config {Board_Interface "ddr3_sdram" }  [get_bd_cells mig_7series_0]
# Note the memory interface generator (MIG takes the "System Clock" (LVDS 200MHz in the VC707) in its input
# and generates one or more clocks that can be made external for use in the PL. At least a clock ui_clk at
# half the input frequency is generated. This is the case here, only the signle-ended ui_clk @100MHz is
# generated.

# Microblaze
# Notes:
# - Do that after configuring the DDR, since the MIG output clock (ui_clk) is used as
#   the clock of the processor.
# - By selecting the cache size, "instruction and data cache" are enabled
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config {local_mem "64KB" ecc "None" cache "32KB" debug_module "Debug Only" axi_periph "Enabled" axi_intc "1" clk "/mig_7series_0/ui_clk (100 MHz)" }  [get_bd_cells microblaze_0]

# Add specific configurations to Microblaze
# Changes with respect to the default configuration:
# - Enable barrel shifter
# - Enable integer multiplier( MUL32)
# - Enable additional machine status register instructions
# - Enable Pattern Comparator
# - Ensure BASIC Debug Module is chosen
# - Set cacheable address corresponding to the DDR3 address range
set_property -dict [list CONFIG.C_USE_MSR_INSTR {1} CONFIG.C_USE_PCMP_INSTR {1} CONFIG.C_USE_BARREL {1} CONFIG.C_USE_HW_MUL {1}] [get_bd_cells microblaze_0]
set_property -dict [list CONFIG.C_DCACHE_HIGHADDR.VALUE_SRC USER CONFIG.C_DCACHE_BASEADDR.VALUE_SRC USER CONFIG.C_ICACHE_HIGHADDR.VALUE_SRC USER CONFIG.C_ICACHE_BASEADDR.VALUE_SRC USER] [get_bd_cells microblaze_0]
set_property -dict [list CONFIG.C_ICACHE_BASEADDR {0x80000000} CONFIG.C_ICACHE_HIGHADDR {0xBFFFFFFF} CONFIG.C_DCACHE_BASEADDR {0x80000000} CONFIG.C_DCACHE_HIGHADDR {0xBFFFFFFF}] [get_bd_cells microblaze_0]
set_property -dict [list CONFIG.C_CACHE_BYTE_SIZE {4096} CONFIG.C_DCACHE_BYTE_SIZE {4096}] [get_bd_cells microblaze_0]

# Configure local memory
set_property range 8K [get_bd_addr_segs {microblaze_0/Data/SEG_dlmb_bram_if_cntlr_Mem}]
set_property range 8K [get_bd_addr_segs {microblaze_0/Instruction/SEG_ilmb_bram_if_cntlr_Mem}]

# Automatically connect the newly added ports M_AXI_DC and M_AXI_IC,
# which are the AXI master interfaces for the data and instruction cache.
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Slave "/microblaze_0_axi_intc/s_axi" Clk "Auto" }  [get_bd_intf_pins microblaze_0/M_AXI_DC]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Slave "/microblaze_0_axi_intc/s_axi" Clk "Auto" }  [get_bd_intf_pins microblaze_0/M_AXI_IC]

# Uartlite

# Set baud rate:
set_property -dict [list CONFIG.C_BAUDRATE {115200}] [get_bd_cells axi_uartlite_0]

# Microblaze Concat (concatenates interrupts)
#  Set number of interrupt ports
set_property -dict [list CONFIG.NUM_PORTS $no_interrupts] [get_bd_cells microblaze_0_xlconcat]

if {$::board == "VC707"} {
	apply_bd_automation -rule xilinx.com:bd_rule:axi_ethernet -config {PHY_TYPE "SGMII" FIFO_DMA "DMA" }  [get_bd_cells axi_ethernet_0]
} elseif {$::board == "VC709"} {


}

######################################################################
#
# Connection automations
#
######################################################################

# Memory Interface Generator
# - Connects the board interface reset to the sys_rst in the MIG
# - Connects the S_AXI interface in the MIG to the AXI interconnect
# - Connects the clock to a differential system clock
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Cached)" Clk "Auto" }  [get_bd_intf_pins mig_7series_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface "reset" }  [get_bd_pins mig_7series_0/sys_rst]

# RS232 UART
# - connects AXI_S interface of the axi_uartlite to the AXI Interconnect
# - connects also the reset and clock ports in the axi_uartlite
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_uartlite_0/S_AXI]

# AXI Timer
# Standard AXI memory-mapped automated connections
# Namely add one more Master interface in the AXI interconnect and connect
# system clock and reset signals
#apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_timer_0/S_AXI]

if {$::board == "VC707"} {
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0/s_axi]
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0_dma/S_AXI_LITE]
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Slave "/mig_7series_0/S_AXI" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0_dma/M_AXI_SG]
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Slave "/mig_7series_0/S_AXI" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0_dma/M_AXI_MM2S]

	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Slave "/mig_7series_0/S_AXI" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0_dma/M_AXI_S2MM]
} elseif {$::board == "VC709"} {


}

# FMcomms2 IF Blocks

	# Create instance: ad9361_comm_0, and set properties
	set ad9361_comm_0 [ create_bd_cell -type ip -vlnv LaPS:user:ad9361_comm:1.0 ad9361_comm_0 ]

	# Create instance: axi_ad9361_0, and set properties
	set axi_ad9361_0 [ create_bd_cell -type ip -vlnv analog.com:user:axi_ad9361:1.0 axi_ad9361_0 ]
	# Configurations for the AD9361:
	#	Device Type: 0 -> SERIES7

	# Create instance: fmcomms2_gpio, and set properties
	set fmcomms2_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 fmcomms2_gpio ]
	set_property -dict [ list CONFIG.C_GPIO_WIDTH {15}  ] $fmcomms2_gpio

	# Create instance: fmcomms2_spi, and set properties
	set fmcomms2_spi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 fmcomms2_spi ]
	set_property -dict [ list CONFIG.C_NUM_SS_BITS {8} CONFIG.C_SCK_RATIO {8} CONFIG.C_USE_STARTUP {0}  ] $fmcomms2_spi

	# Connect the AD9361 as AXI Slave
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_ad9361_0/s_axi]

	# Connect the GPIO as AXI slave
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins fmcomms2_gpio/S_AXI]

	# Connect the SPI as AXI Slave
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins fmcomms2_spi/AXI_LITE]



################################################################################
#
# Manual Connections
#
#
################################################################################

################################################################################
# 	Interrupt Signals
################################################################################

# Concatenate Interrupt Signals (up to 32 can be concatenated)
#  IPs with interrupts:

connect_bd_net [get_bd_pins axi_ethernet_0_dma/mm2s_introut] [get_bd_pins microblaze_0_xlconcat/In0]
connect_bd_net [get_bd_pins axi_ethernet_0_dma/s2mm_introut] [get_bd_pins microblaze_0_xlconcat/In1]
connect_bd_net [get_bd_pins axi_ethernet_0/interrupt] [get_bd_pins microblaze_0_xlconcat/In2]

#################################################################################
## Other connections
#################################################################################

################################AD9361##########################################


if {$::ad9361_mode == "NO_DATA"} {

	create_bd_port -dir O adc_enable_i0
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_enable_i0] [get_bd_ports adc_enable_i0]

	create_bd_port -dir O adc_valid_i0
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_valid_i0] [get_bd_ports adc_valid_i0]

	create_bd_port -dir O -from 15 -to 0 adc_data_i0
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_data_i0] [get_bd_ports adc_data_i0]

	create_bd_port -dir O adc_enable_q0
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_enable_q0] [get_bd_ports adc_enable_q0]

	create_bd_port -dir O adc_valid_q0
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_valid_q0] [get_bd_ports adc_valid_q0]

	create_bd_port -dir O -from 15 -to 0 adc_data_q0
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_data_q0] [get_bd_ports adc_data_q0]

	create_bd_port -dir O adc_enable_i1
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_enable_i1] [get_bd_ports adc_enable_i1]

	create_bd_port -dir O adc_valid_i1
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_valid_i1] [get_bd_ports adc_valid_i1]

	create_bd_port -dir O -from 15 -to 0 adc_data_i1
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_data_i1] [get_bd_ports adc_data_i1]

	create_bd_port -dir O adc_enable_q1
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_enable_q1] [get_bd_ports adc_enable_q1]

	create_bd_port -dir O adc_valid_q1
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_valid_q1] [get_bd_ports adc_valid_q1]

	create_bd_port -dir O -from 15 -to 0 adc_data_q1
	connect_bd_net [get_bd_pins /axi_ad9361_0/adc_data_q1] [get_bd_ports adc_data_q1]

	create_bd_port -dir O dac_enable_i0
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_enable_i0] [get_bd_ports dac_enable_i0]

	create_bd_port -dir O dac_valid_i0
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_valid_i0] [get_bd_ports dac_valid_i0]

	create_bd_port -dir O dac_enable_q0
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_enable_q0] [get_bd_ports dac_enable_q0]

	create_bd_port -dir O dac_valid_q0
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_valid_q0] [get_bd_ports dac_valid_q0]

	create_bd_port -dir O dac_enable_i1
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_enable_i1] [get_bd_ports dac_enable_i1]

	create_bd_port -dir O dac_valid_i1
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_valid_i1] [get_bd_ports dac_valid_i1]

	create_bd_port -dir O dac_enable_q1
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_enable_q1] [get_bd_ports dac_enable_q1]

	create_bd_port -dir O dac_valid_q1
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_valid_q1] [get_bd_ports dac_valid_q1]

	create_bd_port -dir I -from 15 -to 0 dac_data_i0
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_data_i0] [get_bd_ports dac_data_i0]

	create_bd_port -dir I -from 15 -to 0 dac_data_q0
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_data_q0] [get_bd_ports dac_data_q0]

	create_bd_port -dir I -from 15 -to 0 dac_data_i1
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_data_i1] [get_bd_ports dac_data_i1]

	create_bd_port -dir I -from 15 -to 0 dac_data_q1
	connect_bd_net [get_bd_pins /axi_ad9361_0/dac_data_q1] [get_bd_ports dac_data_q1]

} elseif {$::ad9361_mode == "DATA_IF"} {
	#TODO
}


#ad9361 out ports


  # Rx and Tx may not be both used, by to avoid unconnected pins in the IP, connect
  # all of them.

  # RX interface pins

  create_bd_port -dir I rx_clk_in_p
  connect_bd_net [get_bd_pins /axi_ad9361_0/rx_clk_in_p] [get_bd_ports rx_clk_in_p]

  create_bd_port -dir I rx_clk_in_n
  connect_bd_net [get_bd_pins /axi_ad9361_0/rx_clk_in_n] [get_bd_ports rx_clk_in_n]

  create_bd_port -dir I rx_frame_in_p
  connect_bd_net [get_bd_pins /axi_ad9361_0/rx_frame_in_p] [get_bd_ports rx_frame_in_p]

  create_bd_port -dir I rx_frame_in_n
  connect_bd_net [get_bd_pins /axi_ad9361_0/rx_frame_in_n] [get_bd_ports rx_frame_in_n]

  create_bd_port -dir I -from 5 -to 0 rx_data_in_p
  connect_bd_net [get_bd_pins /axi_ad9361_0/rx_data_in_p] [get_bd_ports rx_data_in_p]

  create_bd_port -dir I -from 5 -to 0 rx_data_in_n
  connect_bd_net [get_bd_pins /axi_ad9361_0/rx_data_in_n] [get_bd_ports rx_data_in_n]

  # TX interface pins

  create_bd_port -dir O tx_clk_out_p
  connect_bd_net [get_bd_pins /axi_ad9361_0/tx_clk_out_p] [get_bd_ports tx_clk_out_p]

  create_bd_port -dir O tx_clk_out_n
  connect_bd_net [get_bd_pins /axi_ad9361_0/tx_clk_out_n] [get_bd_ports tx_clk_out_n]

  create_bd_port -dir O tx_frame_out_p
  connect_bd_net [get_bd_pins /axi_ad9361_0/tx_frame_out_p] [get_bd_ports tx_frame_out_p]

  create_bd_port -dir O tx_frame_out_n
  connect_bd_net [get_bd_pins /axi_ad9361_0/tx_frame_out_n] [get_bd_ports tx_frame_out_n]

  create_bd_port -dir O -from 5 -to 0 tx_data_out_p
  connect_bd_net [get_bd_pins /axi_ad9361_0/tx_data_out_p] [get_bd_ports tx_data_out_p]

  create_bd_port -dir O -from 5 -to 0 tx_data_out_n
  connect_bd_net [get_bd_pins /axi_ad9361_0/tx_data_out_n] [get_bd_ports tx_data_out_n]

  # ENSM
  create_bd_port -dir O enable
  connect_bd_net [get_bd_pins /axi_ad9361_0/enable] [get_bd_ports enable]

  create_bd_port -dir O txnrx
  connect_bd_net [get_bd_pins /axi_ad9361_0/txnrx] [get_bd_ports txnrx]

  # clocking

  connect_bd_net [get_bd_pins axi_ad9361_0/clk] [get_bd_pins axi_ad9361_0/l_clk]
  connect_bd_net -net [get_bd_nets mig_7series_0_ui_addn_clk_0] [get_bd_pins axi_ad9361_0/delay_clk] [get_bd_pins mig_7series_0/ui_addn_clk_0]

  # AD9361_COMM IF SPI+GPIO

  # create Ports

  create_bd_port -dir IO -from 3 -to 0 gpio_ctl
  create_bd_port -dir IO gpio_en_agc
  create_bd_port -dir IO gpio_resetb
  create_bd_port -dir IO -from 7 -to 0 gpio_status
  create_bd_port -dir IO gpio_sync
  create_bd_port -dir O -type clk spi_clk
  create_bd_port -dir O spi_csn_0
  create_bd_port -dir I spi_miso
  create_bd_port -dir O spi_mosi

  # gpio IF
  connect_bd_net -net ad9361_comm_0_gpio_io_i [get_bd_pins ad9361_comm_0/gpio_io_i] [get_bd_pins fmcomms2_gpio/gpio_io_i]
  connect_bd_net -net fmcomms2_gpio_gpio_io_o [get_bd_pins ad9361_comm_0/gpio_io_o] [get_bd_pins fmcomms2_gpio/gpio_io_o]
  connect_bd_net -net fmcomms2_gpio_gpio_io_t [get_bd_pins ad9361_comm_0/gpio_io_t] [get_bd_pins fmcomms2_gpio/gpio_io_t]
  connect_bd_net  [get_bd_pins ad9361_comm_0/gpio_resetb] [get_bd_ports gpio_resetb]
  connect_bd_net  [get_bd_pins ad9361_comm_0/gpio_sync] [get_bd_ports gpio_sync]
  connect_bd_net  [get_bd_pins ad9361_comm_0/gpio_en_agc] [get_bd_ports gpio_en_agc]
  connect_bd_net  [get_bd_pins ad9361_comm_0/gpio_status]  [get_bd_ports gpio_status] [get_bd_pins ad9361_comm_0/gpio_status]
  connect_bd_net  [get_bd_pins ad9361_comm_0/gpio_ctl] [get_bd_ports gpio_ctl]
  connect_bd_net  [get_bd_pins ad9361_comm_0/spi_mosi] [get_bd_ports spi_mosi]
  connect_bd_net  [get_bd_pins ad9361_comm_0/spi_clk] [get_bd_ports spi_clk]
  connect_bd_net  [get_bd_pins ad9361_comm_0/spi_miso] [get_bd_ports spi_miso]

  # spi IF
  connect_bd_net -net ad9361_comm_0_io0_i [get_bd_pins ad9361_comm_0/io0_i] [get_bd_pins fmcomms2_spi/io0_i]
  connect_bd_net -net ad9361_comm_0_io1_i [get_bd_pins ad9361_comm_0/io1_i] [get_bd_pins fmcomms2_spi/io1_i]
  connect_bd_net -net ad9361_comm_0_sck_i [get_bd_pins ad9361_comm_0/sck_i] [get_bd_pins fmcomms2_spi/sck_i]
  connect_bd_net -net ad9361_comm_0_spi_csn_0 [get_bd_ports spi_csn_0] [get_bd_pins ad9361_comm_0/spi_csn_0]
  connect_bd_net -net ad9361_comm_0_ss_i [get_bd_pins ad9361_comm_0/ss_i] [get_bd_pins fmcomms2_spi/ss_i]
  connect_bd_net -net fmcomms2_spi_io0_o [get_bd_pins ad9361_comm_0/io0_o] [get_bd_pins fmcomms2_spi/io0_o]
  connect_bd_net -net fmcomms2_spi_sck_o [get_bd_pins ad9361_comm_0/sck_o] [get_bd_pins fmcomms2_spi/sck_o]
  connect_bd_net -net fmcomms2_spi_ss_o [get_bd_pins ad9361_comm_0/ss_o] [get_bd_pins fmcomms2_spi/ss_o]
  connect_bd_net -net [get_bd_nets microblaze_0_Clk] [get_bd_pins fmcomms2_spi/ext_spi_clk] [get_bd_pins mig_7series_0/ui_clk]
