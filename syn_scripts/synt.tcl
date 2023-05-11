proc HitEnter {{message "Hit Enter to continue ==> "}} {
    puts -nonewline $message
    flush stdout
    gets stdin
}
# pause "Hurry, hit enter: "; # Sample usage 1
# pause;                      # Sample usage 2, use default message

# # Read-write message attribute. Limits messages in Genus to 4000 characters.
# # All characters after the 4000 character limit are truncated.
# # To remove this limit, set the attribute to false.
# # However, this may dramatically increase the size of the log file.
# set_attribute truncate false

# # # 1. SET SEARCH PATHS AND TARGET LIBRARY
# # # 2. LOAD HDL FILES
set ROOT "/home/radiocad/se5616ca-s/thesis/WORK"

set SYNT_SCRIPT "${ROOT}/syn_scripts"
set SYNT_OUT    "${ROOT}/OUTPUTS"
set SYNT_REPORT "${ROOT}/REPORTS"

puts "\n\n\n DESIGN FILES \n\n\n"
source $SYNT_SCRIPT/design_setup.tcl

puts "\n\n ANALYZING VHDL FILES \n\n"
set_attribute hdl_vhdl_read_version 2008
read_hdl -vhdl   ${Design_Files_VHDL}

puts "\n\n ANALYZING VERILOG FILES \n\n"
read_hdl -v2001 ${Design_Files_verilog}

# # # 3. PERFORM ELABORATION

# # *** Clock Gating ***
# # To ensure that clock-gating logic is inserted:
# set_attribute lp_insert_clock_gating true
# # Adds a prefix to all clock-gating modules, generated clock nets and ports created by
# # clock-gating insertion:
# lp_clock_gating_prefix lowp

puts "\n\n\n ELABORATE \n\n\n"
elaborate ${DESIGN}

check_design -unresolved
check_design -unloaded
check_design -undriven

# # Resolves naming conflicts by adding a unique suffix to each conflicting signal or component
# # name. This ensures that all names in the design are unique and eliminates any potential
# # naming conflicts.
uniquify ${DESIGN}

# # # 4. APPLY CONSTRAINTS
puts "\n\n\n TIMING CONSTRAINTS \n\n\n"
source $SYNT_SCRIPT/clock.tcl

# # # 5. APPLY OPTIMIZATION SETTINGS
#set_attribute preserve true [find / -inst TOP_inst]
# # To turn off sequential merging on the design
# # For a particular instance use attribute ??optimize_merge_seqs?? to turn off sequential merging.
# set_attribute optimize_merge_flops false
# set_attribute optimize_merge_flops true
# set_attribute optimize_merge_latches false
# set_attribute optimize_merge_latches true

# # To avoid redundant logic removal
# set_attribute delete_unloaded_insts false
# set_attribute delete_unloaded_insts true
# set_attribute delete_unloaded_seqs false
# set_attribute delete_unloaded_seqs true

# # No Limit on log message output
# set_attribute truncate false

# # Set dont_use to FALSE for using mem libraries
# set_dont_use [get_lib_cells /libraries/*/*4096*] FALSE
# set_dont_use [get_lib_cells /libraries/*/*8192*] FALSE
# set_dont_use [get_lib_cells /libraries/*/*2048*] FALSE

# # I cant set as preserve the cell because it is unmapped, lets preserve all the nets on it instead.
set_dont_touch [get_cells -hierarchical *SRAM_WB_BUFFER*] TRUE
set_dont_touch [get_cells -hierarchical *SRAM_IFM_BUFFER*] TRUE
# set_dont_touch [find TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BUFFER_inst/ -net *] TRUE
# set_dont_touch [find TOP_LU_PADS/TOP_inst/SRAM_IFM_inst/SRAM_IFM_BUFFER_inst/ -net *] TRUE

# # set -max constraint to avoid hold timing issues. Note that set_input_delay takes value in nanosecs, hence $time_value_in_ps / 1000.0 (notice the decimal point to treat it as float, otherwise returns 0)
# puts [ expr $InputDelay / 1000.0 ]
# set in_pins_addr_4K_wb_mem [find */*/SRAM_WB_WRAPPER_BLOCK_inst -pin A_4K*]
# set in_pins_addr_8K_1_wb_mem [find */*/SRAM_WB_WRAPPER_BLOCK_inst -pin A_8K_1*]
# set in_pins_addr_8K_2_wb_mem [find */*/SRAM_WB_WRAPPER_BLOCK_inst -pin A_8K_2*]
# set_input_delay -clock $ClkName -max [ expr $InputDelay / 1000.0 ] -add_delay $in_pins_addr_4K_wb_mem
# set_input_delay -clock $ClkName -max [ expr $InputDelay / 1000.0 ] -add_delay $in_pins_addr_8K_1_wb_mem
# set_input_delay -clock $ClkName -max [ expr $InputDelay / 1000.0 ] -add_delay $in_pins_addr_8K_2_wb_mem

# set in_pins_D_4K_wb_mem [find */*/SRAM_WB_WRAPPER_BLOCK_inst -pin D_4K*]
# set in_pins_D_8K_1_wb_mem [find */*/SRAM_WB_WRAPPER_BLOCK_inst -pin D_8K_1*]
# set in_pins_D_8K_2_wb_mem [find */*/SRAM_WB_WRAPPER_BLOCK_inst -pin D_8K_2*]
# set_input_delay -clock $ClkName -max [ expr $InputDelay / 1000.0 ] -add_delay $in_pins_D_4K_wb_mem
# set_input_delay -clock $ClkName -max [ expr $InputDelay / 1000.0 ] -add_delay $in_pins_D_8K_1_wb_mem
# set_input_delay -clock $ClkName -max [ expr $InputDelay / 1000.0 ] -add_delay $in_pins_D_8K_2_wb_mem

# set in_pins_INITN_wb_mem [find */*/SRAM_WB_WRAPPER_BLOCK_inst/ -maxdepth 2 -pin INITN]
# set_input_delay -clock $ClkName -max [ expr $InputDelay / 1000.0 ] -add_delay $in_pins_INITN_wb_mem

# set in_pins_WEN_wb_mem [find */*/SRAM_WB_WRAPPER_BLOCK_inst/ -maxdepth 2 -pin WEN*]
# set_input_delay -clock $ClkName -max [ expr $InputDelay / 1000.0 ] -add_delay $in_pins_WEN_wb_mem

# set in_pins_CSN_wb_mem [find */*/SRAM_WB_WRAPPER_BLOCK_inst/ -maxdepth 2 -pin CSN*]
# set_input_delay -clock $ClkName -max [ expr $InputDelay / 1000.0 ] -add_delay $in_pins_CSN_wb_mem


# # Set constraints to wb memory data-pah to avoid hold violations (300ps)
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[0] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[0]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[1] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[1]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[2] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[2]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[3] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[3]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[4] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[4]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[5] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[5]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[6] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[6]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[7] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[7]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[8] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[8]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[9] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[9]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[10] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[10]
# set_max_delay 300 -from TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BACK_END_inst/A_4K[11] -to TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_WRAPPER_BLOCK_inst/A_4K[11]


# # Optimizing Total Negative Slack
# # ******************************************************************
# # By default, Genus optimizes Worst Negative Slack (WNS) to achieve the timing requirements.
# # During this process, it tries to fix the timing on the most critical path. It also checks
# # the timing #on all the other paths. However, Genus will not work on the other paths if it
# # cannot improve timing on the WNS. To make Genus work on all the paths to reduce the total
# # negative slack (TNS), instead of just WNS, type the following command:
# set_attribute tns_opto true
# # Ensure that you specify the attribute on the root-level (“/”). This attribute instructs
# # Genus to work on all the paths that violate the timing and try to reduce their slack as
# # much as possible. This may cause the run time and area to increase, depending on the
# # design complexity and the number of violating paths.
# # ******************************************************************


# # # 6. SYNTHESIZE
puts "\n\n\n SYN_GENERIC \n\n\n"
syn_generic

puts "\n\n\n SYN_MAP \n\n\n"
syn_map

puts "\n\n\n SYN_OPT \n\n\n"
syn_opt

report timing -lint

# # # 7 & 8 ANALYZE & EXPORT
puts "\n\n\n EXPORT DESIGN \n\n\n"
write_hdl               > ${SYNT_OUT}/${DESIGN}.v
write_sdc -version 2.0  > ${SYNT_OUT}/${DESIGN}.sdc
write_sdf               > ${SYNT_OUT}/${DESIGN}.sdf

puts "\n\n\n REPORTING \n\n\n"
report qor       > $SYNT_REPORT/qor_${DESIGN}.rpt
report area      > $SYNT_REPORT/area_${DESIGN}.rpt
report datapath  > $SYNT_REPORT/datapath_${DESIGN}.rpt
report messages  > $SYNT_REPORT/messages_${DESIGN}.rpt
report gates     > $SYNT_REPORT/gates_${DESIGN}.rpt
report timing    > $SYNT_REPORT/timing_${DESIGN}.rpt

#puts "\n\n\n For Power Estimation on Genus (Joules Power) \n\n\n"
#write_db -script ${SYNT_OUT}/${DESIGN}.tcl -to_file ${SYNT_OUT}/${DESIGN}.db
