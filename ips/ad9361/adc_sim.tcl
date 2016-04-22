# Set the origin directory (relative to the script location)
set origin_dir [file dirname [info script]]

set root_dir "$origin_dir/../"

# Target IP name
set proj_name "adc_sim"

# Create Project
create_project $proj_name $origin_dir/$proj_name -part xc7vx485tffg1761-2

# Set board properties
set_property board_part xilinx.com:vc707:part0:1.2 [current_project]
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

#add files
add_files -norecurse $origin_dir/src/adc-interface.vhd
add_files -norecurse $origin_dir/src/tb/tb-adc-interface.vhd

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


update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
