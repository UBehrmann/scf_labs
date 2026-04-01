

proc check_sva { } {
  vlog ../src_sv/fifo_assertions.sv  ../src_sv/fifo_sv_wrapper.sv
  vcom ../src_vhdl/fifo.vhd -work work    -suppress 7033     -2002

  formal compile -d fifo_sv_wrapper -work work

  formal verify -batch
}

check_sva

