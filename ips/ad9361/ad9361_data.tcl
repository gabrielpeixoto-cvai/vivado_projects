# Set the origin directory (relative to the script location)
set origin_dir [file dirname [info script]]

set root_dir "$origin_dir/../"

# Target IP name
set ip_name "ad9361_data"

# Base repository name
set repo_name "ad9361"

# IP data
set vendor 				"LaPS"
set display_name 		"AD9361 Data Interface"
set description 		"Interfaces AD9361 data input and output ports with DMA"
set vendor_display_name "Laboratório de Processamento de Sinais (LAPS) - UFPA"
set company_url 		"https://laps.ufpa.br"
set taxonomy 			"/Communication_&_Networking/Ethernet /Communication_&_Networking/Telecommunications /UserIP"

# Create Project
create_project $ip_name $origin_dir/$ip_name -part xc7vx485tffg1761-2

# Set board properties
set_property board_part xilinx.com:vc707:part0:1.2 [current_project]
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

#add files
add_files -norecurse $origin_dir/src/ad9361data_top.vhd
add_files -norecurse $origin_dir/src/dac-interface.vhd
add_files -norecurse $origin_dir/src/adc-interface.vhd
add_files -norecurse $origin_dir/src/dac-dma-interface.vhd
add_files -norecurse $origin_dir/src/adc-dma-interface.vhd
add_files -norecurse $origin_dir/src/axis_mux.vhd
add_files -norecurse $origin_dir/src/stream_demux.vhd

######################################################
# Create Required IPs
######################################################

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

# Dual-clock Native FIFO 8192 (depth) x 16 (width)
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 12.0 -module_name native_fifo_8192x16
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM}\
  CONFIG.Input_Data_Width {16}\
  CONFIG.Input_Depth {8192}\
  CONFIG.Write_Data_Count {true}\
  CONFIG.Read_Data_Count {true}\
  CONFIG.Output_Data_Width {16}\
  CONFIG.Output_Depth {8192}\
  CONFIG.Data_Count_Width {13}\
  CONFIG.Write_Data_Count_Width {13}\
  CONFIG.Read_Data_Count_Width {13}\
  CONFIG.Full_Threshold_Assert_Value {8189}\
  CONFIG.Full_Threshold_Negate_Value {8188}] [get_ips native_fifo_8192x16]
generate_target {instantiation_template} [get_files $origin_dir/$ip_name/$ip_name.srcs/sources_1/ip/native_fifo_8192x16/native_fifo_8192x16.xci]



create_ip -name fifo_generator -vendor xilinx.com -library ip -version 12.0 \
 -module_name adc_interface_fifo
set_property -dict [list\
  CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM}\
  CONFIG.Input_Data_Width {64}\
  CONFIG.Input_Depth {128}\
  CONFIG.Output_Data_Width {32}\
  CONFIG.Write_Data_Count {true}\
  CONFIG.Read_Data_Count {true}\
  CONFIG.Output_Depth {256}\
  CONFIG.Data_Count_Width {7}\
  CONFIG.Write_Data_Count_Width {7}\
  CONFIG.Read_Data_Count_Width {8}\
  CONFIG.Full_Threshold_Assert_Value {125}\
  CONFIG.Full_Threshold_Negate_Value {124}\
] [get_ips adc_interface_fifo]
generate_target {instantiation_template} [get_files $origin_dir/$ip_name/$ip_name.srcs/sources_1/ip/adc_interface_fifo/adc_interface_fifo.xci]

#
# Update sources in the hierarchy
#

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if 1 {

# Package project
ipx::package_project -root_dir $origin_dir/$ip_name/$ip_name.srcs -vendor user.org -library user -taxonomy /UserIP -import_files -set_current false

# Edit in IP packager
ipx::unload_core $origin_dir/$ip_name/$ip_name.srcs/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $origin_dir/$ip_name/$ip_name.srcs $origin_dir/$ip_name/$ip_name.srcs/component.xml

set_property vendor $vendor [ipx::current_core]
set_property name $ip_name [ipx::current_core]
set_property display_name $display_name [ipx::current_core]
set_property description $description [ipx::current_core]
set_property vendor_display_name $vendor_display_name [ipx::current_core]
set_property company_url $company_url [ipx::current_core]
set_property taxonomy $taxonomy [ipx::current_core]

# Package Ip
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

}
