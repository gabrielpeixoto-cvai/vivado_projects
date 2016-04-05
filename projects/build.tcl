# November 12, 2015 - Igor F.
#
# TCL Script for assembling the RoE over AD9361 project

if { $::argc > 0 } {
    set i 0
    foreach arg $::argv {
        if { $arg == "-c" || $arg == "--config"} {
            set target_config [lindex $argv [expr $i+1]]
            puts "Target configuration file:\t$target_config"
        }
        incr i
    }
}

# Path definitions

# Set the reference directory for source file relative paths
# Set the reference directory to where the script is
set origin_dir [file dirname [info script]]
set root_dir "$origin_dir/.."

######################################################################
# Default Parameters
#
######################################################################

# ad9361_mode: "DATA_IF", "NO_DATA"
set ::ad9361_mode "DATA_IF"
# board: "VC707", "VC709"
set ::board "VC707"

# Vivado Project Name
set proj_name "sdr_testbed"

######################################################################
# Create Vivado Project and Block Design
#
######################################################################

# Create Project, set board and VHDL
if {$::board == "VC707"} {

create_project $proj_name $origin_dir/$proj_name -part xc7vx485tffg1761-2
set_property board_part xilinx.com:vc707:part0:1.2 [current_project]

} elseif {$::board == "VC709"} {

}

set_property target_language VHDL [current_project]
create_bd_design "block_design"

# Add IP repo
puts "Add IP repositories"
set_property  ip_repo_paths  "$root_dir/analog_devices/library $root_dir/ips $root_dir/interfaces" [current_project]
update_ip_catalog

# Run block desig
puts "Initializing block design"
source $origin_dir/src/bd/block_design.tcl

######################################################################
#
# Constraints
#
######################################################################

# Add constraints file
source $origin_dir/src/constraints/implementation.tcl
file mkdir $origin_dir/$proj_name/$proj_name.srcs/constrs_1
file mkdir $origin_dir/$proj_name/$proj_name.srcs/constrs_1/new
close [ open $origin_dir/$proj_name/$proj_name.srcs/constrs_1/new/implementation.xdc w ]
add_files -fileset constrs_1 $origin_dir/$proj_name/$proj_name.srcs/constrs_1/new/implementation.xdc
write_constraints_file $origin_dir/$proj_name/$proj_name.srcs/constrs_1/new/implementation.xdc
set_property used_in_synthesis false [get_files  $origin_dir/$proj_name/$proj_name.srcs/constrs_1/new/implementation.xdc]

######################################################################
#
# Synthesis
#
######################################################################
if 1 {
    save_bd_design
    validate_bd_design

    ######################################################################
    #
    # Synthesis -> Implementation -> Bitstream Generation
    #
    ######################################################################

    # Generate output products
    generate_target all [get_files $origin_dir/$proj_name/$proj_name.srcs/sources_1/bd/block_design/block_design.bd]

    # Generate HDL wrapper for the block design
    make_wrapper -files [get_files $origin_dir/$proj_name/$proj_name.srcs/sources_1/bd/block_design/block_design.bd] -top
    add_files -norecurse $origin_dir/$proj_name/$proj_name.srcs/sources_1/bd/block_design/hdl/block_design_wrapper.vhd
    update_compile_order -fileset sources_1
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    # Generate bitstream
    launch_runs impl_1 -to_step write_bitstream
}
