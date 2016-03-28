create_project vc707_eth /home/gaburiero/fpga/vc707_eth -part xc7vx485tffg1761-2

set_property board_part xilinx.com:vc707:part0:1.2 [current_project]
create_bd_design "design_1"

create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:2.3 mig_7series_0
apply_board_connection -board_interface "ddr3_sdram" -ip_intf "mig_7series_0/mig_ddr_interface" -diagram "design_1"



create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:9.5 microblaze_0

apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config {local_mem "8KB" ecc "None" cache "8KB" debug_module "Debug & UART" axi_periph "Enabled" axi_intc "1" clk "/mig_7series_0/ui_clk (100 MHz)" }  [get_bd_cells microblaze_0]
apply_bd_automation: Time (s): cpu = 00:00:06 ; elapsed = 00:00:05 . Memory (MB): peak = 6126.531 ; gain = 8.410 ; free physical = 958 ; free virtual = 11586

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Cached)" Clk "Auto" }  [get_bd_intf_pins mig_7series_0/S_AXI]
</mig_7series_0/memmap/memaddr> is being mapped into </microblaze_0/Data> at <0x80000000[ 1G ]>
</mig_7series_0/memmap/memaddr> is being mapped into </microblaze_0/Instruction> at <0x80000000[ 1G ]>
apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface "reset" }  [get_bd_pins mig_7series_0/sys_rst]

apply_bd_automation: Time (s): cpu = 00:00:14 ; elapsed = 00:00:13 . Memory (MB): peak = 6151.594 ; gain = 0.000 ; free physical = 963 ; free virtual = 11589

set_property -name {CONFIG.XML_INPUT_FILE} -value  {mig_a.prj} -objects [get_bd_cells mig_7series_0]
mig_a.prj
set_property -name {CONFIG.RESET_BOARD_INTERFACE} -value  {reset} -objects [get_bd_cells mig_7series_0]
reset
set_property -name {CONFIG.MIG_DONT_TOUCH_PARAM} -value  {Custom} -objects [get_bd_cells mig_7series_0]
Custom
set_property -name {CONFIG.BOARD_MIG_PARAM} -value  {ddr3_sdram} -objects [get_bd_cells mig_7series_0]
ddr3_sdram

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_ethernet:7.0 axi_ethernet_0

create_bd_cell: Time (s): cpu = 00:00:10 ; elapsed = 00:00:09 . Memory (MB): peak = 6430.004 ; gain = 206.777 ; free physical = 760 ; free virtual = 11308
apply_board_connection -board_interface "sgmii" -ip_intf "axi_ethernet_0/sgmii" -diagram "design_1"

apply_board_connection -board_interface "mdio_mdc" -ip_intf "axi_ethernet_0/mdio" -diagram "design_1"

apply_board_connection -board_interface "phy_reset_out" -ip_intf "axi_ethernet_0/phy_rst_n" -diagram "design_1"

apply_board_connection -board_interface "sgmii_mgt_clk" -ip_intf "axi_ethernet_0/mgt_clk" -diagram "design_1"

apply_bd_automation -rule xilinx.com:bd_rule:axi_ethernet -config {PHY_TYPE "SGMII" FIFO_DMA "DMA" }  [get_bd_cells axi_ethernet_0]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0/s_axi]
</axi_ethernet_0/s_axi/Reg0> is being mapped into </microblaze_0/Data> at <0x40C00000[ 256K ]>
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/microblaze_0 (Periph)" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0_dma/S_AXI_LITE]
</axi_ethernet_0_dma/S_AXI_LITE/Reg> is being mapped into </microblaze_0/Data> at <0x41E00000[ 64K ]>
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Slave "/mig_7series_0/S_AXI" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0_dma/M_AXI_SG]
</mig_7series_0/memmap/memaddr> is being mapped into </axi_ethernet_0_dma/Data_SG> at <0x80000000[ 1G ]>
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Slave "/mig_7series_0/S_AXI" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0_dma/M_AXI_MM2S]
</mig_7series_0/memmap/memaddr> is being mapped into </axi_ethernet_0_dma/Data_MM2S> at <0x80000000[ 1G ]>
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Slave "/mig_7series_0/S_AXI" Clk "Auto" }  [get_bd_intf_pins axi_ethernet_0_dma/M_AXI_S2MM]
</mig_7series_0/memmap/memaddr> is being mapped into </axi_ethernet_0_dma/Data_S2MM> at <0x80000000[ 1G ]>



set_property -dict [list CONFIG.NUM_PORTS {3}] [get_bd_cells microblaze_0_xlconcat]


connect_bd_net [get_bd_pins axi_ethernet_0/interrupt] [get_bd_pins microblaze_0_xlconcat/In0]
connect_bd_net [get_bd_pins axi_ethernet_0_dma/mm2s_introut] [get_bd_pins microblaze_0_xlconcat/In1]
connect_bd_net [get_bd_pins axi_ethernet_0_dma/s2mm_introut] [get_bd_pins microblaze_0_xlconcat/In2]
