bscflags = -keep-fires -aggressive-conditions -Xc++ -D_GLIBCXX_USE_CXX11_ABI=0
add_bscflags = +RTS -K4000M -RTS -check-assert -keep-fires -opt-undetermined-vals -remove-false-rules -remove-empty-rules -remove-starved-rules -remove-dollar -unspecified-to 0 -show-schedule -cross-info
bsvdir = ./common:./bsv
build_dir = build
src = bsv/FFT.bsv

verilog: $(src)
	mkdir -p build
	bsc -u -verilog -elab -vdir $(build_dir) -bdir $(build_dir) -info-dir $(build_dir) $(bscflags) $(add_bscflags) -p +:$(bsvdir) -g mkFFT $^

clean:
	rm -rf build
