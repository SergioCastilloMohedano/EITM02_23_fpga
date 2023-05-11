# ALL values are in picosecond

#200MHz
set PERIOD 5000
set ClkTop $DESIGN
set ClkDomain $DESIGN
set ClkName clk_p
set ClkLatency 250
#set ClkRise_uncertainity 250
#set ClkFall_uncertainity 250
set ClkRise_uncertainity 0
set ClkFall_uncertainity 0
set ClkSlew 250
set InputDelay 250
set OutputDelay 250

#125MHz
#set PERIOD 8000
#set ClkTop $DESIGN
#set ClkDomain $DESIGN
#set ClkName clk_p
#set ClkLatency 400
#set ClkRise_uncertainity 400
#set ClkFall_uncertainity 400
#set ClkSlew 400
#set InputDelay 400
#set OutputDelay 400

#1MHz
#set PERIOD 1000000
#set ClkTop $DESIGN
#set ClkDomain $DESIGN
#set ClkName clk_p
#set ClkLatency 50000
#set ClkRise_uncertainity 250
#set ClkFall_uncertainity 250
#set ClkRise_uncertainity 0
#set ClkFall_uncertainity 0
#set ClkSlew 50000
#set InputDelay 50000
#set OutputDelay 50000


# check usr/hidden/cmp/joajox/scripts/ for more detailed scripting

#REMEBER TO CHANGE THE -port ClkxC* to the actual name of clock port/pin in your design

define_clock -name $ClkName -period $PERIOD -design $ClkTop -domain $ClkDomain [find /designs/TOP_LU_PADS/ports_in/clk_p]

set_attribute clock_network_late_latency $ClkLatency $ClkName
set_attribute clock_source_late_latency $ClkLatency $ClkName

set_attribute clock_setup_uncertainty $ClkLatency $ClkName
set_attribute clock_hold_uncertainty $ClkLatency $ClkName

set_attribute slew_rise $ClkRise_uncertainity $ClkName
set_attribute slew_fall $ClkFall_uncertainity $ClkName

external_delay -input $InputDelay -clock [find / -clock $ClkName] -name in_con [find /des* -port ports_in/*]
external_delay -output $OutputDelay -clock [find / -clock $ClkName] -name out_con [find /des* -port ports_out/*]

#set in_ports  [find port { "reset_p" "NL_start_p" }]
#set out_ports [find port { "NL_ready_p" "NL_finished_p" }]

# Define input delays according to the virtual clock(s)
#set_input_delay [expr 0.20 * $PERIOD] -clock clk_p -add_delay $in_ports

# Define output delays according to the virtual clock(s)
#set_output_delay [expr 0.20 * $PERIOD] -clock clk_p -add_delay $out_ports

