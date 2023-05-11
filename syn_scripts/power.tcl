##################  remove any previous designs 
remove_design -all

################### set up power analysis mode #####################
# step 0: Define Top Module name 
set TOP TOP_LU_PADS

################### set up power analysis mode #####################
# step 1: enalbe analysis mode 
set power_enable_analysis true
# set power_analysis_mode time_based
set power_analysis_mode averaged

####################### set up libaries ############################
# step 2: link to your design libary 

### Make sure you choose the same files and paths as you have used in
### synthesis and pnr stage

set search_path "\
/usr/hidden/cmp/s28v15a/C28SOI_SC_8_CLK_LL/5.3-08.81/libs \
/usr/hidden/cmp/s28v15a/C28SOI_SC_8_CORE_LL/5.1-11.81/libs \
/usr/hidden/cmp/mem2016.s28/SPHD_HIPERF_160523__146640/3.3.a-00@20160524.0/libs \
/usr/hidden/cmp/mem2016.s28/DPHD_HIPERF_160523__146639/2.3.a-00@20160524.0/libs \
/usr/hidden/cmp/mem2015.s28/SPHD_HIPERF_151009__141457/3.2-00@20151009.0/libs \
/home/radiocad/se5616ca-s/thesis/LU_PADS_DIG_2020"

#SPHD_HIPERF_160523 -> 8Kx32 SP
#DPHD_HIPERF_160523 -> 2Kx32 DP
#SPHD_HIPERF_151009 -> 4Kx32 SP


set link_path   "* \
C28SOI_SC_8_CLK_LL_tt28_1.00V_0.00V_0.00V_0.00V_25C.db \
C28SOI_SC_8_CORE_LL_tt28_1.00V_0.00V_0.00V_0.00V_25C.db \
SPHD_HIPERF_160523_tt28_1.00V_25C_RCTYP.db \
DPHD_HIPERF_160523_tt28_1.00V_25C_RCTYP.db \
SPHD_HIPERF_151009_tt28_1.00V_25C_RCTYP.db \
LU_PADS.db"

####################### design input    ############################
# svr_enable_vpp true for allowing preprocessor directives in verilog compiler (for memories verilog files)
# set svr_enable_vpp true
# step 3: read your design (netlist) & link design
read_verilog /home/radiocad/se5616ca-s/thesis/WORK/OUTPUTS/TOP_LU_PADS.v
current_design $TOP
link_design -force

####################### timing constraint ##########################
# step 4: setup timing constraint (or read sdc file)
puts "\n\n\n\nreading sdc\n"
read_sdc -version 2.0 /home/radiocad/se5616ca-s/thesis/WORK/OUTPUTS/TOP_LU_PADS_PT.sdc

####################### Back annotate     ##########################
# step 5: back annotate delay information (read sdf file)
# read_parasitics /PATH_TO_SPEF/YOUR_PNR_SPEF_PARASITICS.spef
read_sdf -type sdf_max /home/radiocad/se5616ca-s/thesis/WORK/OUTPUTS/TOP_LU_PADS.sdf

################# read switching activity file #####################
# step 6: read vcd file obtained from post-layout (syn) simulation
# read_vcd -strip_path "/[string tolower medianfilter_tb/dut]" /PATH_TO_VCD/YOUR_VCD_FILE.vcd
puts "\n\n\n\nreading saif\n"
read_saif /export/space/se5616ca-s/thesis/TOP_LU_PADS.saif -strip_path top_lu_pads_tb/inst_TOP_UUT

####################### analysis and report #################
# step 7: Analysis the power
check_power
update_power

####################### report  #################
# step 8: output report
report_power -verbose > /home/radiocad/se5616ca-s/thesis/WORK/REPORTS/power.rpt
report_timing -delay_type min -max_paths 10 > /home/radiocad/se5616ca-s/thesis/WORK/REPORTS/timing_hold.rpt
report_timing -delay_type max -max_paths 10 > /home/radiocad/se5616ca-s/thesis/WORK/REPORTS/timing_setup.rpt

