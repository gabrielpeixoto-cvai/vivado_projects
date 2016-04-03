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
