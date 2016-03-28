# Set the origin directory (relative to the script location)
set origin_dir [file dirname [info script]]

set root_dir "$origin_dir/../"

# Target IP name
set ip_name "ad9361_comm"

# Base repository name
set repo_name "radio_over_ethernet"

# IP data
set vendor 				"LaPS"
set display_name 		"ad9361_comm"
set description 		"Routes SPI and GPIO pins for better interface with FMComms2 board"
set vendor_display_name "Laboratório de Processamento de Sinais (LAPS) - UFPA"
set company_url 		"https://laps.ufpa.br"
set taxonomy 			"/UserIP"

# Create Project
create_project $ip_name $origin_dir/$ip_name -part xc7vx485tffg1761-2

# Set board properties
set_property board_part xilinx.com:vc707:part0:1.2 [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Verilog [current_project]

# Add sources
add_files -norecurse $origin_dir/src/ad9361comm_top.v
add_files -norecurse $origin_dir/src/ad_iobuf.v

######################################################
# Create Required IPs
######################################################

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

#
# Finish Packing
#

# Package Ip
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

}
