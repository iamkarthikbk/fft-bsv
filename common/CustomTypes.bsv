
import Complex::*;
import FixedPoint::*;
import CustomReg::*;
`include "fft.defines"

export CustomTypes::*;
export CustomReg::*;

typedef `fft_points FFT_POINTS; // 8-pt fft. this needs to be changed to 32 for comparinig with hls.
typedef `sample_size SampleSize;
typedef TLog#(FFT_POINTS) FFT_LOG_POINTS;
typedef Int#(SampleSize) Sample;
typedef FixedPoint#(SampleSize, SampleSize) FPSample;
typedef Complex#(FPSample) ComplexSample;

// Turn a real Sample into a ComplexSample.
function ComplexSample tocmplx(Sample x);
    return cmplx(fromInt(x), 0);
endfunction

// Extract the real component from complex.
function Sample frcmplx(ComplexSample x);
    return unpack(truncate(x.rel.i));
endfunction



