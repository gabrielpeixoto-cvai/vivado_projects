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

if {!$::bypass_fronthaul} {
	# 2 extra interrupt ports when AXI Ethernet is present
	incr no_interrupts 2;
}

if {$::cpri_clk == "SI5324"} {
		# 1 extra interrupt ports for the IIC when SI5324 is used
	incr no_interrupts;
}

if {$::sync_mode == "PTP"} {
	# 3 extra interrupt ports for the PTP Tx, Rx and Timer
	incr no_interrupts 3;
}

if {$::data_source == "DMA"} {
	# mm2s_introut in the DMA read channel
	incr no_interrupts;
}

if {$::data_sink == "DMA"} {
	# s2mm_introut in the DMA write channel
	incr no_interrupts;
}

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
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:2.0 axi_timer_0

if {!$::bypass_fronthaul} {
	# AXI Ethernet
	create_bd_cell -type ip -vlnv xilinx.com:ip:axi_ethernet:7.0 axi_ethernet_0
	# Connect the MAC to the PHY via the Serial-gigabit media-independent Interface (SGMII):
	apply_board_connection -board_interface "sgmii" -ip_intf "axi_ethernet_0/sgmii" -diagram "block_design"
	# Connect the PHY to the MDIO interface, through which its registers are managed
	apply_board_connection -board_interface "mdio_mdc" -ip_intf "axi_ethernet_0/mdio" -diagram "block_design"
	apply_board_connection -board_interface "phy_reset_out" -ip_intf "axi_ethernet_0/phy_rst_n" -diagram "block_design"
	apply_board_connection -board_interface "sgmii_mgt_clk" -ip_intf "axi_ethernet_0/mgt_clk" -diagram "block_design"
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

# Interrupt controller

# When DMA is used as data source, in order to prevent preemption by interrupts
# of lower priority, nested interrupts are enabled in the interrupt controller.
if {$::data_source == "DMA"} {
	set_property -dict [list CONFIG.C_HAS_ILR {1}] \
	[get_bd_cells microblaze_0_axi_intc]
}

# Uartlite

# Set baud rate:
set_property -dict [list CONFIG.C_BAUDRATE {115200}] [get_bd_cells axi_uartlite_0]

# AXI Ethernet
# Connect AXI Streaming of AXI Ethernet to a FIFO (an instance of an AXI4-Stream FIFO core)
if {!$::bypass_fronthaul} {
	apply_bd_automation -rule xilinx.com:bd_rule:axi_ethernet -config {PHY_TYPE "SGMII" FIFO_DMA "FIFO" }  [get_bd_cells axi_ethernet_0]

# Note: the AXI4-Stream FIFO core converts AXI4/AXI4-Lite transactions to and from AXI4-Stream transactions
# It has one AXI memory mapped interface that connects to the processor, and the 3 AXI Stream interfaces
# required to interface with the AXI Ethernet core (TXC, TXD and RXD).
# TXD - Transmit data, mm2s (memory mapped to stream)
# TXC - Transmit control (used by AXI Ethernet for e.g. VLAN features), mm2s
# RXD - Receive data, s2mm (stream to memory mapped)

	if {$::sync_mode == "PTP"} {
		set_property -dict [list CONFIG.ENABLE_AVB {true}] [get_bd_cells axi_ethernet_0]
	}
}

# Microblaze Concat (concatenates interrupts)
#  Set number of interrupt ports
set_property -dict [list CONFIG.NUM_PORTS $no_interrupts] [get_bd_cells microblaze_0_xlconcat]


######################################################################
#
# Connection automations
#
######################################################################

# Clock and rest board interfaces
# Not necessary, keep here and remove after really checking that is not necessary
#apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface "sys_diff_clock" }  [get_bd_intf_pins clk_wiz_1/CLK_IN1_D]
#apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface "reset" }  [get_bd_pins clk_wiz_1/reset]
#apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface "reset" }  [get_bd_pins rst_clk_wiz_1_100M/ext_reset_in]

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
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_timer_0/S_AXI]

# AXI Ethernet
# Connect the AXI Ethernet and the Ethernet AXI-Stream FIFO, both of which have AXI memory-mapped
# interfaces for communication with the processor.
# Notes:
# - All the AXI Stream input clocks of the AXI Ethernet core must use the same clock (axis_clk
#   @ 100 MHz) as the one used in AXI4-Stream FIFO core.
# - AXI Ethernet has also an AXI4-Lite interface used by the processor to configure registers
#
# - AXI Ethernet has three clock sources:
#     1) ref_clk -> stable clock (200MHz on 7 series)
#                   Note a clocking wizard is automatically instantiated to generate a 200MHz
#                   clock from a stable 100MHz clock.
#
#     2) mgt_clk -> external reference differential clock of 125MHz used to drive GTX/GTP serial
#                   transceiver in all SGMII configurations.
#
#                   From VC707 manual:
#                   "An Integrated Circuit Systems ICS844021I chip (U2) generates a high-quality,
#                   low-jitter, 125 MHz LVDS clock from a 25 MHz crystal (X3). This clock is sent
#                   to FPGA U1, Bank 113 GTX transceiver (clock pins AH8 (P) and AH7 (N)) driving
#                   the SGMII interface".
#
#     3) axis_clk = s_axi_lite_clk -> AXI clock @ 100 Mhz (same as the processor clock).
#
if {!$::bypass_fronthaul} {
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0/s_axi]
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0_fifo/S_AXI]
}

######################################################################
#
# UFA13 Radio over Ethernet IP
# 	Vivado was crashing when the IP was added before the previous
# blocks. When added in the following order (after all block and
# connection automations) it works in 2015.2.
#
######################################################################
create_bd_cell -type ip -vlnv LaPS:user:radio_over_ethernet:1.0 radio_over_ethernet_0
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins radio_over_ethernet_0/S_AXI]
# Set CPRI Source and Sink
set_property -dict [list CONFIG.data_source "$::data_source"] [get_bd_cells radio_over_ethernet_0]
set_property -dict [list CONFIG.data_sink "$::data_sink"] [get_bd_cells radio_over_ethernet_0]
# Define whether or not to bypass the Fronthaul
set_property -dict [list CONFIG.bypass_fronthaul "$::bypass_fronthaul"] [get_bd_cells radio_over_ethernet_0]

if {$::data_source == "DMA" || $::data_sink == "DMA"} {
	# If the CPRI mode determines DMA source, the RoE IP requires an
	# AXI DMA instance
	create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
	# Configure the DMA with scatter gather mode enabled.
	# Note "Read Channel" is relative to the memory, namely that the memory is
	# read and the data goes via AXI Streaming to the downstream processing chain.
	# The opposite for the "Write Channel". The two channels are enabled based
	# on the conditions for the Data Source and Data Sink in the RoE.
	set_property -dict [list CONFIG.c_include_sg {1} \
	CONFIG.c_include_mm2s [expr {$::data_source eq "DMA" ? "1" : "0"}] \
	CONFIG.c_mm2s_burst_size {128} \
	CONFIG.c_sg_length_width {23} \
	CONFIG.c_include_s2mm [expr {$::data_sink eq "DMA" ? "1" : "0"}] \
	CONFIG.c_sg_include_stscntrl_strm {0}] [get_bd_cells axi_dma_0]

	# Then apply block automation
	# Connect the AXI-Lite interface to the Microblaze via the AXI interconnect
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
	{Master "/microblaze_0 (Periph)" Clk "Auto" } \
	[get_bd_intf_pins axi_dma_0/S_AXI_LITE]

	# Connect the Scatter Gather Engine to the MIG
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
	{Slave "/mig_7series_0/S_AXI" Clk "Auto" }  \
	[get_bd_intf_pins axi_dma_0/M_AXI_SG]

	# Connect the MM2S interface to the MIG via the AXI interconnect
	if {$::data_source == "DMA"} {
	  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
		{Slave "/mig_7series_0/S_AXI" Clk "Auto" } \
		[get_bd_intf_pins axi_dma_0/M_AXI_MM2S]

		# Connect the RoE IP to the AXI DMA
		connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] \
		[get_bd_intf_pins radio_over_ethernet_0/s_axis_dma]
	}

	# Connect the S2MM interface to the MIG via the AXI interconnect
	if {$::data_sink == "DMA"} {
		apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
		{Slave "/mig_7series_0/S_AXI" Clk "Auto" } \
		[get_bd_intf_pins axi_dma_0/M_AXI_S2MM]

		connect_bd_intf_net [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM] \
		[get_bd_intf_pins radio_over_ethernet_0/m_axis_dma]
	}
}

# FMcomms2 IF Blocks
if {($::data_source == "ADC") || ($::data_sink == "DAC")} {
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
}

# FMcomms2 connections
if {$::data_source == "ADC"} {
  connect_bd_net -net axi_ad9361_0_adc_data_i0 [get_bd_pins axi_ad9361_0/adc_data_i0] [get_bd_pins radio_over_ethernet_0/rx_i0_data]
  connect_bd_net -net axi_ad9361_0_adc_data_i1 [get_bd_pins axi_ad9361_0/adc_data_i1] [get_bd_pins radio_over_ethernet_0/rx_i1_data]
  connect_bd_net -net axi_ad9361_0_adc_data_q0 [get_bd_pins axi_ad9361_0/adc_data_q0] [get_bd_pins radio_over_ethernet_0/rx_q0_data]
  connect_bd_net -net axi_ad9361_0_adc_data_q1 [get_bd_pins axi_ad9361_0/adc_data_q1] [get_bd_pins radio_over_ethernet_0/rx_q1_data]
  connect_bd_net -net axi_ad9361_0_adc_enable_i0 [get_bd_pins axi_ad9361_0/adc_enable_i0] [get_bd_pins radio_over_ethernet_0/rx_i0_enable]
  connect_bd_net -net axi_ad9361_0_adc_enable_i1 [get_bd_pins axi_ad9361_0/adc_enable_i1] [get_bd_pins radio_over_ethernet_0/rx_i1_enable]
  connect_bd_net -net axi_ad9361_0_adc_enable_q0 [get_bd_pins axi_ad9361_0/adc_enable_q0] [get_bd_pins radio_over_ethernet_0/rx_q0_enable]
  connect_bd_net -net axi_ad9361_0_adc_enable_q1 [get_bd_pins axi_ad9361_0/adc_enable_q1] [get_bd_pins radio_over_ethernet_0/rx_q1_enable]
  connect_bd_net -net axi_ad9361_0_adc_valid_i0 [get_bd_pins axi_ad9361_0/adc_valid_i0] [get_bd_pins radio_over_ethernet_0/rx_i0_valid]
  connect_bd_net -net axi_ad9361_0_adc_valid_i1 [get_bd_pins axi_ad9361_0/adc_valid_i1] [get_bd_pins radio_over_ethernet_0/rx_i1_valid]
  connect_bd_net -net axi_ad9361_0_adc_valid_q0 [get_bd_pins axi_ad9361_0/adc_valid_q0] [get_bd_pins radio_over_ethernet_0/rx_q0_valid]
  connect_bd_net -net axi_ad9361_0_adc_valid_q1 [get_bd_pins axi_ad9361_0/adc_valid_q1] [get_bd_pins radio_over_ethernet_0/rx_q1_valid]
}

if {$::data_sink == "DAC"} {
  connect_bd_net -net axi_ad9361_0_dac_enable_i0 [get_bd_pins axi_ad9361_0/dac_enable_i0] [get_bd_pins radio_over_ethernet_0/tx_i0_enable]
  connect_bd_net -net axi_ad9361_0_dac_enable_i1 [get_bd_pins axi_ad9361_0/dac_enable_i1] [get_bd_pins radio_over_ethernet_0/tx_i1_enable]
  connect_bd_net -net axi_ad9361_0_dac_enable_q0 [get_bd_pins axi_ad9361_0/dac_enable_q0] [get_bd_pins radio_over_ethernet_0/tx_q0_enable]
  connect_bd_net -net axi_ad9361_0_dac_enable_q1 [get_bd_pins axi_ad9361_0/dac_enable_q1] [get_bd_pins radio_over_ethernet_0/tx_q1_enable]
  connect_bd_net -net axi_ad9361_0_dac_valid_i0 [get_bd_pins axi_ad9361_0/dac_valid_i0] [get_bd_pins radio_over_ethernet_0/tx_i0_valid]
  connect_bd_net -net axi_ad9361_0_dac_valid_i1 [get_bd_pins axi_ad9361_0/dac_valid_i1] [get_bd_pins radio_over_ethernet_0/tx_i1_valid]
  connect_bd_net -net axi_ad9361_0_dac_valid_q0 [get_bd_pins axi_ad9361_0/dac_valid_q0] [get_bd_pins radio_over_ethernet_0/tx_q0_valid]
  connect_bd_net -net axi_ad9361_0_dac_valid_q1 [get_bd_pins axi_ad9361_0/dac_valid_q1] [get_bd_pins radio_over_ethernet_0/tx_q1_valid]
  connect_bd_net -net radio_over_ethernet_0_tx_i0_data [get_bd_pins axi_ad9361_0/dac_data_i0] [get_bd_pins radio_over_ethernet_0/tx_i0_data]
  connect_bd_net -net radio_over_ethernet_0_tx_i1_data [get_bd_pins axi_ad9361_0/dac_data_i1] [get_bd_pins radio_over_ethernet_0/tx_i1_data]
  connect_bd_net -net radio_over_ethernet_0_tx_q0_data [get_bd_pins axi_ad9361_0/dac_data_q0] [get_bd_pins radio_over_ethernet_0/tx_q0_data]
  connect_bd_net -net radio_over_ethernet_0_tx_q1_data [get_bd_pins axi_ad9361_0/dac_data_q1] [get_bd_pins radio_over_ethernet_0/tx_q1_data]
}

if {$::cpri_clk == "MMCM"} {
	# CPRI Clock Wizard
	create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:5.1 cpri_clk_wiz

	# Configure for 7.68 MHz
	set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {7.68} CONFIG.MMCM_DIVCLK_DIVIDE {5} CONFIG.MMCM_CLKFBOUT_MULT_F {42.000} CONFIG.MMCM_CLKOUT0_DIVIDE_F {109.375} CONFIG.CLKOUT1_JITTER {452.882} CONFIG.CLKOUT1_PHASE_ERROR {310.955}] [get_bd_cells cpri_clk_wiz]

	# Configure the input port as coming from a clock used by other logic (add global buffer)
	set_property -dict [list CONFIG.PRIM_SOURCE {Global_buffer}] [get_bd_cells cpri_clk_wiz]
	# Add dynamic reconfiguration to the MMCM
	set_property -dict [list CONFIG.USE_DYN_RECONFIG {true}] [get_bd_cells cpri_clk_wiz]
	# Run block automation (connect S_AXI to microblaze)
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins cpri_clk_wiz/s_axi_lite]
	# Connect its aresetn
	connect_bd_net -net [get_bd_nets rst_mig_7series_0_100M_peripheral_aresetn] [get_bd_pins cpri_clk_wiz/s_axi_aresetn] [get_bd_pins rst_mig_7series_0_100M/peripheral_aresetn]

	# Make the locked port external, in order to connect it to an LED
	create_bd_port -dir O locked
	connect_bd_net [get_bd_pins /cpri_clk_wiz/locked] [get_bd_ports locked]
	set_property name GPIO_LED_0 [get_bd_ports locked]

} elseif { $::cpri_clk == "SI5324" } {
	# AXI IIC
	create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.0 axi_iic_0
	apply_board_connection -board_interface "iic_main" -ip_intf "axi_iic_0/IIC" -diagram "block_design"
	# Connect to microblaze
	apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_iic_0/S_AXI]

	# Instantiate Si5324 IP for mapping external clocks
	create_bd_cell -type ip -vlnv LaPS:user:si5324:1.0 si5324_0

	# Make its diff clocks (input and output) external
	create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_clock_rtl:1.0 out_ckin
	connect_bd_intf_net [get_bd_intf_pins si5324_0/out_ckin] [get_bd_intf_ports out_ckin]
	create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 in_ckout
	connect_bd_intf_net [get_bd_intf_pins si5324_0/in_ckout] [get_bd_intf_ports in_ckout]

	# Set names
	set_property name si5324_ckin [get_bd_intf_ports out_ckin]
	set_property name si5324_ckout [get_bd_intf_ports in_ckout]

	# Connect its reset ports
	connect_bd_net -net [get_bd_nets rst_mig_7series_0_100M_peripheral_aresetn] [get_bd_pins si5324_0/sys_aresetn] [get_bd_pins rst_mig_7series_0_100M/peripheral_aresetn]
	create_bd_port -dir O -type rst aresetn
	connect_bd_net [get_bd_pins /si5324_0/aresetn] [get_bd_ports aresetn]

	# Set external reset pin name
	set_property name si5324_rst [get_bd_ports aresetn]
}

# Check if the RoE Clock should be output and connect to
if {$output_clock == 1} {
	set_property -dict [list CONFIG.output_clock {true}] [get_bd_cells radio_over_ethernet_0]
	create_bd_port -dir O cpri_clk_out
	connect_bd_net [get_bd_pins /radio_over_ethernet_0/cpri_clk_out] [get_bd_ports cpri_clk_out]
}

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
#    - AXI Timer
#    - AXI Uartlite
#    - AXI Ethernet
#    - AXI Ethernet FIFO
#    - UFA13 Radio over Ethernet
# Note the order in which these interrupts are connected in the "Concat" block
# corresponds to the priority order by default. In this case, the timer is connected
# to In0 (LSB), thus receives highest priority.
set iInterrupt 0

# DMA Read Channel (highest priority)
if { $::data_source == "DMA" } {
	connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
	incr iInterrupt 1
}

# PTP Interrupts
if {$::sync_mode == "PTP"} {
	connect_bd_net [get_bd_pins axi_ethernet_0/interrupt_ptp_timer] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
	incr iInterrupt 1
	connect_bd_net [get_bd_pins axi_ethernet_0/interrupt_ptp_rx] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
	incr iInterrupt 1
	connect_bd_net [get_bd_pins axi_ethernet_0/interrupt_ptp_tx] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
	incr iInterrupt 1
}

# DMA Write Channel
if { $::data_sink == "DMA" } {
	connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
	incr iInterrupt 1
}

# Timer and Uartlite
connect_bd_net [get_bd_pins axi_timer_0/interrupt] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
incr iInterrupt 1
connect_bd_net [get_bd_pins axi_uartlite_0/interrupt] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
incr iInterrupt 1

# AXi Ethernet and Ethernet FIFO
if {!$::bypass_fronthaul} {
	connect_bd_net [get_bd_pins axi_ethernet_0/interrupt] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
	incr iInterrupt 1
	connect_bd_net [get_bd_pins axi_ethernet_0_fifo/interrupt] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
	incr iInterrupt 1
}

# IIC
if { $::cpri_clk == "SI5324" } {
	connect_bd_net [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
	incr iInterrupt 1
}

# Radio over Ethernet (lowest priority)
connect_bd_net [get_bd_pins radio_over_ethernet_0/interrupt] [get_bd_pins microblaze_0_xlconcat/In$iInterrupt]
incr iInterrupt 1

################################################################################
# Other connections
################################################################################

# UFA13 IP
# First delete automated connections between TxC, TxD and RXD
if {!$::bypass_fronthaul} {
	delete_bd_objs [get_bd_intf_nets axi_ethernet_0_fifo_AXI_STR_TXC]
	delete_bd_objs [get_bd_intf_nets axi_ethernet_0_fifo_AXI_STR_TXD]
	delete_bd_objs [get_bd_intf_nets axi_ethernet_0_m_axis_rxd]
	# Then insert RoE IP between AXI FIFO and AXI Ethernet, connecting accordingly
	connect_bd_intf_net [get_bd_intf_pins radio_over_ethernet_0/m_axis_ethTxc]  [get_bd_intf_pins axi_ethernet_0/s_axis_txc]
	connect_bd_intf_net [get_bd_intf_pins radio_over_ethernet_0/m_axis_ethTxd]  [get_bd_intf_pins axi_ethernet_0/s_axis_txd]
	connect_bd_intf_net [get_bd_intf_pins radio_over_ethernet_0/s_axis_ethRxd]   [get_bd_intf_pins axi_ethernet_0/m_axis_rxd]
	connect_bd_intf_net [get_bd_intf_pins radio_over_ethernet_0/s_axis_fifoTxc] [get_bd_intf_pins axi_ethernet_0_fifo/AXI_STR_TXC]
	connect_bd_intf_net [get_bd_intf_pins radio_over_ethernet_0/s_axis_fifoTxd] [get_bd_intf_pins axi_ethernet_0_fifo/AXI_STR_TXD]
	connect_bd_intf_net [get_bd_intf_pins radio_over_ethernet_0/m_axis_fifoRx]  [get_bd_intf_pins axi_ethernet_0_fifo/AXI_STR_RXD]
}

if {$::cpri_clk == "MMCM"} {
	# Connect CPRI clock from the clock wizard to the RoE IP
	connect_bd_net [get_bd_pins radio_over_ethernet_0/cpri_clk] [get_bd_pins cpri_clk_wiz/clk_out1]
	# And pass the system clock to the clock wizard as reference
	connect_bd_net -net [get_bd_nets microblaze_0_Clk] [get_bd_pins cpri_clk_wiz/clk_in1] [get_bd_pins mig_7series_0/ui_clk]
} elseif { $::cpri_clk == "SI5324" } {

	#
	# Connect Si5324 to RoE
	#
	# Two alternatives:
	#
	# Alternative #1: Direct Connection
	#       Si5324 ----------------------------------------> RoE
	# Alternative #2: When AD9361 is used
	#   Si5324 ---->     AD9361     ---->    RoE
	#                 (out of FPGA)       (back inside the FPGA)
	#
	if {($::data_source == "ADC") || ($::data_sink == "DAC")} {
		# When the AD9361 is used, the Si5324 is configured to output 40 MHz,
		# instead of the CPRI clock directly. This is because 40 MHz is the
		# frequency that is fed to the fmcomms2 as external clock. The AD9361
		# returns a clock whose frequency is 4 times the sampling frequency back in
		# its "locked clock" (l_clk) pin. This is the clock that is connected the
		# RoE core "cpri_clk" input:
		connect_bd_net -net [get_bd_nets axi_ad9361_0_l_clk] \
		                    [get_bd_pins radio_over_ethernet_0/cpri_clk] \
		                    [get_bd_pins axi_ad9361_0/l_clk]
	} else {
		# Connect the Si5324 output clock directly to the RoE CPRI clock
		connect_bd_net [get_bd_pins si5324_0/out_clk] \
		               [get_bd_pins radio_over_ethernet_0/cpri_clk]
	}
	# In any case, connect the Si5324 output for external use to an external port
	create_bd_port -dir O si5324_out_clk_ext
	connect_bd_net [get_bd_pins /si5324_0/out_clk_ext] \
	               [get_bd_ports si5324_out_clk_ext]
	#
	# Determine the reference passed to Si5324
	#
	if {$::sync_mode == "PTP"} {
		# Pass the synchronized clk8k as reference to the Si5324
		connect_bd_net [get_bd_pins axi_ethernet_0/clk8k] \
		               [get_bd_pins si5324_0/ref_clk]

		if {$output_clock == 1} {
			# And also make the clk8k available for external observation
			create_bd_port -dir O clk8k
			connect_bd_net [get_bd_pins /axi_ethernet_0/clk8k] [get_bd_ports clk8k]
		}
	} else {
		# When PTP is not used, the reference can't be clk8k from AVB
		if {$::bypass_fronthaul == 0} {
			# Pass the Ethernet GTX clk as reference to the Si5324
			connect_bd_net [get_bd_pins axi_ethernet_0/userclk2_out] [get_bd_pins si5324_0/ref_clk]
		} else {
			# If the Fronthaul is bypassed, AXI Ethernet is not present in the design.
			# Then, pass the 200 MHz clock from the MIG as reference to Si5324.
			connect_bd_net [get_bd_pins mig_7series_0/ui_addn_clk_0] [get_bd_pins si5324_0/ref_clk]
		}
	}
}

#AD9361 IF

#ad9361 out ports


if {($::data_source == "ADC") || ($::data_sink == "DAC")} {
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
}
