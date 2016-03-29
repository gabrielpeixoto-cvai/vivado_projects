proc write_constraints_file { str_filepath } {
  set constraints_file [open $str_filepath  w+]

  if {$::cpri_clk == "MMCM"} {
    # "Locked" indication on LED
    puts $constraints_file {set_property PACKAGE_PIN AM39 [get_ports GPIO_LED_0]}
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports GPIO_LED_0]}

  } elseif { $::cpri_clk == "SI5324" } {

    # Si5324 Input clocks
    puts $constraints_file {set_property PACKAGE_PIN AW32 [get_ports si5324_ckin_clk_p]}
    puts $constraints_file {set_property IOSTANDARD LVDS [get_ports si5324_ckin_clk_p]}
    puts $constraints_file {set_property PACKAGE_PIN AW33 [get_ports si5324_ckin_clk_n]}
    puts $constraints_file {set_property IOSTANDARD LVDS [get_ports si5324_ckin_clk_n]}

    # Si5324 output clocks
    puts $constraints_file {set_property PACKAGE_PIN AD8 [get_ports si5324_ckout_clk_p]}
    puts $constraints_file {set_property PACKAGE_PIN AD7 [get_ports si5324_ckout_clk_n]}

    # Si5324 reset pin
    puts $constraints_file {set_property PACKAGE_PIN AT36 [get_ports si5324_rst]}
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports si5324_rst]}
  }

  # When the AD9361 is used, output the Si5324 clock passing through the FPGA
  # to the SMA pin
  # Connect to "USER_SMA_CLOCK_P"
  puts $constraints_file {\
    set_property PACKAGE_PIN AJ32 [get_ports si5324_out_clk_ext]\
  }
  puts $constraints_file {\
    set_property IOSTANDARD LVCMOS18 [get_ports si5324_out_clk_ext]\
  }

  if {$::output_clock == 1} {
    # Connect to "USER_SMA_GPIO_P"
    puts $constraints_file {set_property PACKAGE_PIN AN31 [get_ports cpri_clk_out]}
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports cpri_clk_out]}

    if {$::sync_mode == "PTP"} {
      # Connect to "USER_SMA_GPIO_N"
      puts $constraints_file {set_property PACKAGE_PIN AP31 [get_ports clk8k]}
      puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports clk8k]}
    }
  }

  # False pahts
  puts $constraints_file {set_false_path -through block_design_i/radio_over_ethernet_0/U0/cpriSource_i/rst_internal}

  #ad9361 related constrains
  if {($::data_source == "ADC") || ($::data_sink == "DAC")} {

    #axi_ad9361
    puts $constraints_file {set_property -dict {PACKAGE_PIN K39 IOSTANDARD LVDS DIFF_TERM 1} [get_ports rx_clk_in_p] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN K40 IOSTANDARD LVDS DIFF_TERM 1} [get_ports rx_clk_in_n] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN J40 IOSTANDARD LVDS DIFF_TERM 1} [get_ports rx_frame_in_p] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN J41 IOSTANDARD LVDS DIFF_TERM 1} [get_ports rx_frame_in_n] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN P41 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_p[0]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN N41 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_n[0]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN M42 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_p[1]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN L42 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_n[1]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN H40 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_p[2]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN H41 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_n[2]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN M41 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_p[3]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN L41 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_n[3]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN K42 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_p[4]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN J42 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_n[4]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN G41 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_p[5]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN G42 IOSTANDARD LVDS DIFF_TERM 1} [get_ports {rx_data_in_n[5]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN M37 IOSTANDARD LVDS} [get_ports tx_clk_out_p] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN M38 IOSTANDARD LVDS} [get_ports tx_clk_out_n] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN R42 IOSTANDARD LVDS} [get_ports tx_frame_out_p] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN P42 IOSTANDARD LVDS} [get_ports tx_frame_out_n] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN F40 IOSTANDARD LVDS} [get_ports {tx_data_out_p[0]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN F41 IOSTANDARD LVDS} [get_ports {tx_data_out_n[0]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN R40 IOSTANDARD LVDS} [get_ports {tx_data_out_p[1]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN P40 IOSTANDARD LVDS} [get_ports {tx_data_out_n[1]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN H39 IOSTANDARD LVDS} [get_ports {tx_data_out_p[2]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN G39 IOSTANDARD LVDS} [get_ports {tx_data_out_n[2]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN N38 IOSTANDARD LVDS} [get_ports {tx_data_out_p[3]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN M39 IOSTANDARD LVDS} [get_ports {tx_data_out_n[3]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN N39 IOSTANDARD LVDS} [get_ports {tx_data_out_p[4]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN N40 IOSTANDARD LVDS} [get_ports {tx_data_out_n[4]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN M36 IOSTANDARD LVDS} [get_ports {tx_data_out_p[5]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN L37 IOSTANDARD LVDS} [get_ports {tx_data_out_n[5]}] }

    #GPIO
    puts $constraints_file {set_property -dict {PACKAGE_PIN Y29 IOSTANDARD LVCMOS18} [get_ports {gpio_status[0]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN Y30 IOSTANDARD LVCMOS18} [get_ports {gpio_status[1]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN N28 IOSTANDARD LVCMOS18} [get_ports {gpio_status[2]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN N29 IOSTANDARD LVCMOS18} [get_ports {gpio_status[3]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN R28 IOSTANDARD LVCMOS18} [get_ports {gpio_status[4]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN P28 IOSTANDARD LVCMOS18} [get_ports {gpio_status[5]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN P30 IOSTANDARD LVCMOS18} [get_ports {gpio_status[6]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN N31 IOSTANDARD LVCMOS18} [get_ports {gpio_status[7]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN R30 IOSTANDARD LVCMOS18} [get_ports {gpio_ctl[0]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN P31 IOSTANDARD LVCMOS18} [get_ports {gpio_ctl[1]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN K29 IOSTANDARD LVCMOS18} [get_ports {gpio_ctl[2]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN K30 IOSTANDARD LVCMOS18} [get_ports {gpio_ctl[3]}] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN W30 IOSTANDARD LVCMOS18} [get_ports gpio_en_agc] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN W31 IOSTANDARD LVCMOS18} [get_ports gpio_sync] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN L29 IOSTANDARD LVCMOS18} [get_ports gpio_resetb] }

    puts $constraints_file {set_property -dict {PACKAGE_PIN K37 IOSTANDARD LVCMOS18} [get_ports enable] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN K38 IOSTANDARD LVCMOS18} [get_ports txnrx] }

    #SPI
    puts $constraints_file {set_property PACKAGE_PIN J30 [get_ports spi_csn_0] }
    puts $constraints_file {set_property IOSTANDARD LVCMOS18 [get_ports spi_csn_0] }
    puts $constraints_file {set_property PULLUP true [get_ports spi_csn_0] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN H30 IOSTANDARD LVCMOS18} [get_ports spi_clk] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN J31 IOSTANDARD LVCMOS18} [get_ports spi_mosi] }
    puts $constraints_file {set_property -dict {PACKAGE_PIN H31 IOSTANDARD LVCMOS18} [get_ports spi_miso] }

    # Primary clock constraints: analog devices uses 4. See:
    # master/projects/fmcomms2/vc707/system_constr.xdc
    puts $constraints_file {create_clock -name rx_clk -period 4 [get_ports rx_clk_in_p]}
    puts $constraints_file {create_clock -name ad9361_clk -period 4 [get_pins block_design_i/axi_ad9361_0/clk]}

  }


close $constraints_file
}
