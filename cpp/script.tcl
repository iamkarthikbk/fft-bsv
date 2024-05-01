open_project fft32
set_top FFT
add_files fft.cpp
open_solution "scatter6_axilite"
set_part {xc7z020clg400-1} -tool vivado
create_clock -period 5 -name default
csim_design -clean
csynth_design
export_design -format ip_catalog
exit