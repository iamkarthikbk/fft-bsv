
import Complex::*;
import FixedPoint::*;
import CustomReg::*;

export CustomTypes::*;
export CustomReg::*;

typedef Int#(16) Sample;
typedef Complex#(FixedPoint#(16, 16)) ComplexSample;

// Turn a real Sample into a ComplexSample.
function ComplexSample tocmplx(Sample x);
    return cmplx(fromInt(x), 0);
endfunction

// Extract the real component from complex.
function Sample frcmplx(ComplexSample x);
    return unpack(truncate(x.rel.i));
endfunction


typedef 8 FFT_POINTS; // 8-pt fft. this needs to be changed to 32 for comparinig with hls.
typedef TLog#(FFT_POINTS) FFT_LOG_POINTS;

