#!/usr/bin/tclsh

# Main proc at the end #

proc tlmvm_compil { } {

    set currentDir [pwd]

    cd ../tlmvm/comp
    do ../scripts/compile.do
    cd $currentDir

    vmap tlmvm ../tlmvm/comp/tlmvm
}

#------------------------------------------------------------------------------
proc vhdl_compil { } {
    global Path_VHDL
    global Path_TB
    puts "\nVHDL compilation :"

    vcom -2008 $Path_VHDL/log_pkg.vhd
    vcom -2008 $Path_VHDL/fifo.vhd
    vcom -2008 $Path_TB/random_pkg.vhd
    vcom -2008 $Path_TB/fifo_tb.vhd
}

#------------------------------------------------------------------------------
proc sim_start {FIFOSIZE DATASIZE TESTCASE} {

    vsim -voptargs="+acc" -t 1ns -GFIFOSIZE=$FIFOSIZE -GDATAWIDTH=$DATASIZE -GTESTCASE=$TESTCASE work.fifo_tb
    if {[file exists wave.do] == 0} {
	add wave -r *
    } else { 
	do wave.do
    }
    wave refresh
    run -all
}

#------------------------------------------------------------------------------
proc do_all {FIFOSIZE DATASIZE TESTCASE} {
    tlmvm_compil
    vhdl_compil
    sim_start $FIFOSIZE $DATASIZE $TESTCASE
}

## MAIN #######################################################################

# Compile folder ----------------------------------------------------
if {[file exists work] == 0} {
    vlib work
}

# tlmvm_compil

puts -nonewline "  Path_VHDL => "
set Path_VHDL     "../src_vhdl"
set Path_TB       "../src_tb"

global Path_VHDL
global Path_TB

# start of sequence -------------------------------------------------
if {$argc==1} {
    if {[string compare $1 "all"] == 0} {
	puts "All simulation"
	do_all 8 8 0
    } elseif {[string compare $1 "comp_vhdl"] == 0} {
	puts "VHDL compilation"
	vhdl_compil
    } elseif {[string compare $1 "sim"] == 0} {
	puts "Sim option"
	sim_start 8 8 0
    }    
} elseif {$argc==2} { # No testcase given
    puts "No testcase specified"
    do_all $1 $2 0
} elseif {$argc==3} { # Specific test case
    puts "Testcase specified"
    do_all $1 $2 $3
} else {
    puts "Default values"
    do_all 8 8 0
}

