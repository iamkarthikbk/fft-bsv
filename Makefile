bscflags = -keep-fires -aggressive-conditions -Xc++ -D_GLIBCXX_USE_CXX11_ABI=0
add_bscflags = +RTS -K4000M -RTS -check-assert -keep-fires -opt-undetermined-vals -remove-false-rules -remove-empty-rules -remove-starved-rules -remove-dollar -unspecified-to 0 -show-schedule -cross-info
bsvdir = ./common:./fft
build_dir = build
src = fft/FFT.bsv

verilog: $(src)
	mkdir -p bscdir
	bsc -u -verilog -elab -vdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) $(add_bscflags) -p +:$(bsvdir) -g mkFFT $^

clean:
	rm -rf bscdir out out.so
