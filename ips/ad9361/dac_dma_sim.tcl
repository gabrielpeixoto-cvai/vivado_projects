# Set the origin directory (relative to the script location)
set origin_dir [file dirname [info script]]

set root_dir "$origin_dir/../"

# Target IP name
set proj_name "dac-dma-sim"

# Create Project
create_project $proj_name $origin_dir/$proj_name -part xc7vx485tffg1761-2

# Set board properties
set_property board_part xilinx.com:vc707:part0:1.2 [current_project]
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

#add files
add_files -norecurse $origin_dir/src/dac-dma-interface.vhd
add_files -norecurse $origin_dir/src/stream_demux.vhd
add_files -norecurse $origin_dir/src/tb/tb-dac_dma_interface.vhd


create_ip -name fifo_generator -vendor xilinx.com -library ip -version 12.0 -module_name fifo_axis_m_d64_w32_s_w32
set_property -dict [list CONFIG.INTERFACE_TYPE {AXI_STREAM} \
  CONFIG.Clock_Type_AXI {Independent_Clock} \
  CONFIG.TDATA_NUM_BYTES {4} \
  CONFIG.TUSER_WIDTH {0} \
  CONFIG.Input_Depth_axis {64} \
  CONFIG.Underflow_Flag_AXI {true} \
  CONFIG.Overflow_Flag_AXI {true} \
  CONFIG.TSTRB_WIDTH {4} \
  CONFIG.TKEEP_WIDTH {4} \
  CONFIG.FIFO_Implementation_wach {Independent_Clocks_Distributed_RAM} \
  CONFIG.Full_Threshold_Assert_Value_wach {15} \
  CONFIG.Empty_Threshold_Assert_Value_wach {13} \
  CONFIG.FIFO_Implementation_wdch {Independent_Clocks_Block_RAM} \
  CONFIG.Empty_Threshold_Assert_Value_wdch {1021} \
  CONFIG.FIFO_Implementation_wrch {Independent_Clocks_Distributed_RAM} \
  CONFIG.Full_Threshold_Assert_Value_wrch {15} \
  CONFIG.Empty_Threshold_Assert_Value_wrch {13} \
  CONFIG.FIFO_Implementation_rach {Independent_Clocks_Distributed_RAM} \
  CONFIG.Full_Threshold_Assert_Value_rach {15} \
  CONFIG.Empty_Threshold_Assert_Value_rach {13} \
  CONFIG.FIFO_Implementation_rdch {Independent_Clocks_Block_RAM} \
  CONFIG.Empty_Threshold_Assert_Value_rdch {1021} \
  CONFIG.FIFO_Implementation_axis {Independent_Clocks_Block_RAM} \
  CONFIG.Full_Threshold_Assert_Value_axis {63} \
  CONFIG.Empty_Threshold_Assert_Value_axis {61}
] [get_ips fifo_axis_m_d64_w32_s_w32]
generate_target {instantiation_template} [get_files $origin_dir/$ip_name/$ip_name.srcs/sources_1/ip/fifo_axis_m_d64_w32_s_w32/fifo_axis_m_d64_w32_s_w32.xci]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
