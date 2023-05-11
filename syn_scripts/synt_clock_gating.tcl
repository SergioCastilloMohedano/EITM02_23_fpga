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
read_hdl -vhdl   ${Design_Files_VHDL_CG}

puts "\n\n ANALYZING VERILOG FILES \n\n"
read_hdl -v2001 ${Design_Files_verilog}

# # # 3. PERFORM ELABORATION

# # *** Clock Gating ***
# # To ensure that clock-gating logic is inserted:
set_attribute lp_insert_clock_gating true
# # In some cases, simulation issues occur when trying to gate flops that do not have
# # a set or reset pin. To prevent simulation issues, set to true the next root
# # attribute to only use this algorithm for flops with set or reset pins.
# set_attribute lp_clock_gating_infer_enable true
# # Adds a prefix to all clock-gating modules, generated clock nets and ports created by
# # clock-gating insertion:
set_attribute lp_clock_gating_prefix lowp

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
# # *** Clock Gating ***
# # If the user-defined clock-gating module does not contain any test logic, you must
# # set this attribute to none:
set_attribute lp_clock_gating_control_point none [current_design]
# # Assign Clock Gating Module
set_attribute lp_clock_gating_module my_CG_MOD [find / -subdesign my_CG_MOD]
# # If the library has an integrated clock-gating cell, but this cell has either a
# # 'dont_use' or a 'dont_touch' attribute set to 'true', the cell is considered unusable.
# # To make the cell usable, set the 'avoid' attribute for the lib_cell to 'false' in Genus.
# # If the library has no integrated clock-gating cell, you can set the
# # 'lp_insert_discrete_clock_gating_logic' root attribute to 'true' to allow Genus to create
# # discrete clock-gating logic for the insertion.
set_attribute avoid false [find / -libcell *CNHLSX24_P0]
# # Avoid the Use of Scan FLops in the design:
set_dont_use [find / -libcell *SDFP*] TRUE

# # Set dont_use to FALSE for using mem libraries
set_dont_use [get_lib_cells /libraries/*/*4096*] FALSE
set_dont_use [get_lib_cells /libraries/*/*8192*] FALSE
set_dont_use [get_lib_cells /libraries/*/*2048*] FALSE

# # If cells are mapped:
set_dont_touch [get_cells -hierarchical *SRAM_WB_BUFFER*] TRUE
set_dont_touch [get_cells -hierarchical *SRAM_IFM_BUFFER*] TRUE
# # Otherwise, its not possible to set as preserve the cell because it is unmapped. If so, lets preserve all the nets on it instead:
# set_dont_touch [find TOP_LU_PADS/TOP_inst/SRAM_WB_inst/SRAM_WB_BUFFER_inst/ -net *] TRUE
# set_dont_touch [find TOP_LU_PADS/TOP_inst/SRAM_IFM_inst/SRAM_IFM_BUFFER_inst/ -net *] TRUE

# # Optimizing Total Negative Slack
# # ******************************************************************
# # By default, Genus optimizes Worst Negative Slack (WNS) to achieve the timing requirements.
# # During this process, it tries to fix the timing on the most critical path. It also checks
# # the timing on all the other paths. However, Genus will not work on the other paths if it
# # cannot improve timing on the WNS. To make Genus work on all the paths to reduce the total
# # negative slack (TNS), instead of just WNS, type the following command:
# set_attribute tns_opto true
# # Ensure that you specify the attribute on the root-level (“/”). This attribute instructs
# # Genus to work on all the paths that violate the timing and try to reduce their slack as
# # much as possible. This may cause the run time and area to increase, depending on the
# # design complexity and the number of violating paths.
# # ******************************************************************

# # DO NOT OPTIMIZE PEs
# # Not possible, cos cant set as preserve constant drivers
# set_dont_touch [find /designs/TOP_LU_PADS/instances_hier/TOP_inst/instances_hier/NOC_inst/instances_hier/*.PE_inst -net *] TRUE
# # Not possible, cos not fully mapped.
# set_dont_touch [get_cells -hierarchical *PE_inst*] TRUE

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


