# Copyright (c) 2024 Tobias Scheipel, David Beikircher, Florian Riedl
# Embedded Architectures & Systems Group, Graz University of Technology
# SPDX-License-Identifier: MIT
# ---------------------------------------------------------------------
# File: synth.tcl

# ---------------------------------------------------------------------
# 1. Parse Arguments (ADDED)
# ---------------------------------------------------------------------
if { $argc != 3 } {
    puts "Error: Invalid number of arguments."
    puts "Usage: vivado -mode batch -source synth.tcl -tclargs <PART> <XDC_PATH> <BOARD_DEFINE>"
    exit 1
}

set TARGET_PART  [lindex $argv 0]
set XDC_FILE     [lindex $argv 1]
set BOARD_DEFINE [lindex $argv 2]

puts "------------------------------------------------"
puts "  Synthesis Configuration"
puts "  Part:  $TARGET_PART"
puts "  XDC:   $XDC_FILE"
puts "  Board: $BOARD_DEFINE"
puts "------------------------------------------------"

# Get root directory
set ROOT [file normalize [file dirname [info script]]/..]

# Supress some warnings
# identifier <name> is used before its declaration
set_msg_config -id {Synth 8-6901} -suppress

# <name> is already implicitly declared earlier
set_msg_config -id {Synth 8-8895} -suppress

# Unused sequential element <name>_reg was removed
set_msg_config -id {Synth 8-6014} -string {test_reg_reg} -suppress
set_msg_config -id {Synth 8-6014} -string {test_stb_reg} -suppress

# Port <port> in module <module> is either unconnected or has no load
set_msg_config -id {Synth 8-7129} -string {wishbone_buttons} -suppress
set_msg_config -id {Synth 8-7129} -string {wishbone_leds} -suppress
set_msg_config -id {Synth 8-7129} -string {wishbone_switches} -suppress
set_msg_config -id {Synth 8-7129} -string {wishbone_test} -suppress
set_msg_config -id {Synth 8-7129} -string {wishbone_uart} -suppress

# initial value of parameter '<parameter>' is omitted [<path>]
set_msg_config -id {Synth 8-9661} -suppress

# Parallel synthesis criteria is not met
set_msg_config -id {Synth 8-7080} -suppress

# Define source files
set SOURCES {
    defines/csr.sv
    defines/op.sv
    defines/instruction.sv
    defines/pipeline_status.sv
    defines/constants.sv
    defines/forwarding.sv
    defines/clk_params.sv

    lib/*.sv
    lib/peripherals/*.sv
    lib/wishbone/*.sv

    ref/*.sv
    rtl/*.sv

    synth/top.sv
}

foreach source $SOURCES {
    read_verilog -sv [glob -directory $ROOT $source]
}

# ---------------------------------------------------------------------
# 2. Read Constraints (DYNAMIC)
# ---------------------------------------------------------------------
read_xdc $XDC_FILE

# Read memory file
read_mem $ROOT/build/test/c/bootloader/init.mem

# ---------------------------------------------------------------------
# 3. Synthesize (DYNAMIC)
# ---------------------------------------------------------------------
# We pass the board define (e.g. BOARD_ZYBO=1) to the Verilog compiler
synth_design -top top -part $TARGET_PART -verilog_define ${BOARD_DEFINE}=1

opt_design

# Synthesis reports
file mkdir reports
report_timing_summary -file reports/timing_syn.rpt
report_power -file reports/power_syn.rpt
report_design_analysis -file reports/design_analysis.rpt

# Place and Route
place_design
phys_opt_design
route_design
phys_opt_design

# PnR Reports
report_timing_summary -file reports/timing_pnr.rpt
report_utilization -file reports/utilization_pnr.rpt
report_power -file reports/power_pnr.rpt

# Generate bitstream
write_bitstream -force -bin hades-v.bit