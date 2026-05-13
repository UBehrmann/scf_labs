#!/usr/bin/tclsh

#------------------------------------------------------------------------------
# Architecture selection
#------------------------------------------------------------------------------
if {$argc > 0} {
  set ARCH $1
} else {
  set ARCH "cmb"
}

#------------------------------------------------------------------------------
proc vhdl_compil { } {
  global Path_VHDL
  global ARCH
  puts "\n=== VHDL Compilation ($ARCH) ==="
  vcom -2008 $Path_VHDL/fir_filter_pkg.vhd
  vcom -2008 $Path_VHDL/fir_filter__$ARCH.vhd
  puts "VHDL files compiled successfully"
}

#------------------------------------------------------------------------------
proc sv_compil { } {
  global Path_TB
  global ARCH
  puts "\n=== SystemVerilog Compilation ($ARCH) ==="
  vlog -sv $Path_TB/fir_filter_tb__$ARCH.sv
  puts "SystemVerilog testbench compiled successfully"
}

#------------------------------------------------------------------------------
proc sim_fir_filter { } {
  global ARCH
  puts "\n=== Starting FIR Filter Simulation ($ARCH) ==="
  vsim -t 1ns work.fir_filter_tb
  add wave -r *
  wave refresh
  run -all
}

#------------------------------------------------------------------------------
proc compile_all { } {
  vhdl_compil
  sv_compil
}

#------------------------------------------------------------------------------
proc do_all_fir { } {
  compile_all
  sim_fir_filter
}

## MAIN #######################################################################

if {[file exists work] == 0} {
  mkdir work
  vlib work
  vmap work work
}

set Path_VHDL "../src_vhdl"
set Path_TB   "../src_tb"

global Path_VHDL
global Path_TB
global ARCH

do_all_fir
