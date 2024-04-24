create_project fft_bsv 
set_top mkFFT
add_files bscdir/mkFFT.v
open_solution "solution1"
set_part {xc7a35tcpg236-1} -tool vivado
create_clock -period 10 -name default
synth_design