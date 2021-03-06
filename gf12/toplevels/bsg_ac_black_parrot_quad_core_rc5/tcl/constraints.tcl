########################################
##
## Clock Setup
##

set bp_clk_name        "bp_clk"         ;# main clock running block parrot

set bp_clk_period_ps       2000
#set bp_clk_period_ps       1666
set bp_clk_uncertainty_per 3.0
#set bp_clk_uncertainty_ps  [expr min([expr ${bp_clk_period_ps}*(${bp_clk_uncertainty_per}/100.0)], 50)]
set bp_clk_uncertainty_ps 20

########################################
##
## BP Tile Constraints
##

if { ${DESIGN_NAME} == "bp_tile_node" } {

  set core_clk_name           ${bp_clk_name}
  set core_clk_period_ps      ${bp_clk_period_ps}
  set core_clk_uncertainty_ps ${bp_clk_uncertainty_ps}

  set input_delay_per  20.0
  set output_delay_per 20.0

  set core_input_delay_ps  [expr ${core_clk_period_ps}*(${input_delay_per}/100.0)]
  set core_output_delay_ps [expr ${core_clk_period_ps}*(${output_delay_per}/100.0)]

  set driving_lib_cell "SC7P5T_INVX2_SSC14R"
  set load_lib_pin     "SC7P5T_INVX8_SSC14R/A"

  # Reg2Reg
  create_clock -period ${core_clk_period_ps} -name ${core_clk_name} [get_ports *clk*]
  set_clock_uncertainty ${core_clk_uncertainty_ps} [get_clocks ${core_clk_name}]
  
  # In2Reg
  set core_input_pins [filter_collection [all_inputs] "name!~*clk*"]
  set_driving_cell -no_design_rule -lib_cell ${driving_lib_cell} [remove_from_collection [all_inputs] [get_ports *clk*]]
  set_input_delay ${core_input_delay_ps} -clock ${core_clk_name} ${core_input_pins}
  
  # Reg2Out
  set core_output_pins [all_outputs]
  set_load [load_of [get_lib_pin */${load_lib_pin}]] ${core_output_pins}
  set_output_delay ${core_output_delay_ps} -clock ${core_clk_name} ${core_output_pins}

  # This timing assertion for the RF is only valid in designs that do not do simultaneous read and write, or do not use the read value when it writes
  # Check your ram generator to see what it permits
  foreach_in_collection cell [filter_collection [all_macro_cells] "full_name=~*_regfile*rf*"] {
    set_disable_timing $cell -from CLKA -to CLKB
    set_disable_timing $cell -from CLKB -to CLKA
  }

  set_false_path -from [get_ports *did*]
  set_false_path -from [get_ports *cord*]

  # Derate
  set cells_to_derate [list]
  append_to_collection cells_to_derate [get_cells -quiet -hier -filter "ref_name=~gf14_*"]
  append_to_collection cells_to_derate [get_cells -quiet -hier -filter "ref_name=~IN12LP_*"]
  if { [sizeof $cells_to_derate] > 0 } {
    foreach_in_collection cell $cells_to_derate {
      set_timing_derate -cell_delay -early 0.97 $cell
      set_timing_derate -cell_delay -late  1.03 $cell
      set_timing_derate -cell_check -early 0.97 $cell
      set_timing_derate -cell_check -late  1.03 $cell
    }
  }
  #report_timing_derate

  set_app_var compile_keep_original_for_external_references true

  current_design *pipe_fma*
  create_clock -period ${core_clk_period_ps} [get_ports "clk_i"]
  set_optimize_registers true -check_design
  uniquify -force
  ungroup -flatten [get_cells -hier]

  current_design *pipe_aux*
  create_clock -period ${core_clk_period_ps} [get_ports "clk_i"]
  set_optimize_registers true -check_design
  uniquify -force
  ungroup -flatten [get_cells -hier]

  current_design *pipe_mem*
  create_clock -period ${core_clk_period_ps} [get_ports "clk_i"]
  set_optimize_registers true -check_design
  uniquify -force
  ungroup -flatten [get_cells -hier]

  current_design bp_tile_node

########################################
##
## Top-level Constraints
##

} elseif { ${DESIGN_NAME} == "bsg_chip" } {

  # Ungrouping
  #=================
  # Ungroup meshes so that buffers do not get inserted automatically between adjacent pins
  set_ungroup [get_cells -hier coh_req_mesh]
  set_ungroup [get_cells -hier coh_cmd_mesh]
  set_ungroup [get_cells -hier coh_resp_mesh]
  set_ungroup [get_cells -hier mem_mesh]
  set_ungroup [get_cells -hier cmd_mesh]
  set_ungroup [get_cells -hier resp_mesh]

  set cells_to_derate [list]
  append_to_collection cells_to_derate [get_cells -quiet -hier -filter "ref_name=~gf14_*"]
  if { [sizeof $cells_to_derate] > 0 } {
    foreach_in_collection cell $cells_to_derate {
      set_timing_derate -cell_delay -early 0.97 $cell
      set_timing_derate -cell_delay -late  1.03 $cell
      set_timing_derate -cell_check -early 0.97 $cell
      set_timing_derate -cell_check -late  1.03 $cell
    }
  }
  #report_timing_derate

########################################
##
## Unknown design...
##
} else {

  puts "BSG-error: No constraints found for design (${DESIGN_NAME})!"

}

