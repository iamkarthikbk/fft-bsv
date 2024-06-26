
import ClientServer ::*;
import Complex      ::*;
import FIFO         ::*;
import CustomReg    ::*;
import GetPut       ::*;
import Real         ::*;
import Vector       ::*;
import BRAMFIFO     ::*;
import CustomTypes  ::*;
import Multiplier   ::*;
`include "fft.defines"

typedef Server#(
    Vector#(FFT_POINTS, ComplexSample),
    Vector#(FFT_POINTS, ComplexSample)
) FFT;

// Get the appropriate twiddle factor for the given stage and index.
// This computes the twiddle factor statically.
function ComplexSample getTwiddle(Integer stage, Integer index, Integer points);
    Integer i = ((2*index)/(2 ** (log2(points)-stage))) * (2 ** (log2(points)-stage));
    return cmplx(fromReal(cos(fromInteger(i)*pi/fromInteger(points))),
                    fromReal(-1*sin(fromInteger(i)*pi/fromInteger(points))));
endfunction

// Generate a table of all the needed twiddle factors.
// The table can be used for looking up a twiddle factor dynamically.
typedef Vector#(FFT_LOG_POINTS, Vector#(TDiv#(FFT_POINTS, 2), ComplexSample)) TwiddleTable;
function TwiddleTable genTwiddles();
    TwiddleTable twids = newVector;
    for (Integer s = 0; s < valueof(FFT_LOG_POINTS); s = s+1) begin
        for (Integer i = 0; i < valueof(TDiv#(FFT_POINTS, 2)); i = i+1) begin
            twids[s][i] = getTwiddle(s, i, valueof(FFT_POINTS));
        end
    end
    return twids;
endfunction

// Given the destination location and the number of points in the fft, return
// the source index for the permutation.
function Integer permute(Integer dst, Integer points);
    Integer src = ?;
    if (dst < points/2) begin
        src = dst*2;
    end else begin
        src = (dst - points/2)*2 + 1;
    end
    return src;
endfunction

// Reorder the given vector by swapping words at positions
// corresponding to the bit-reversal of their indices.
// The reordering can be done either as as the
// first or last phase of the FFT transformation.
function Vector#(FFT_POINTS, ComplexSample) bitReverse(Vector#(FFT_POINTS,ComplexSample) inVector);
    Vector#(FFT_POINTS, ComplexSample) outVector = newVector();
    for(Integer i = 0; i < valueof(FFT_POINTS); i = i+1) begin
        Bit#(FFT_LOG_POINTS) reversal = reverseBits(fromInteger(i));
        outVector[reversal] = inVector[i];
    end
    return outVector;
endfunction

// 2-way Butterfly
function Vector#(2, ComplexSample) bfly2(Vector#(2, ComplexSample) t, ComplexSample k);
    ComplexSample m = t[1] * k;

    Vector#(2, ComplexSample) z = newVector();
    z[0] = t[0] + m;
    z[1] = t[0] - m;

    return z;
endfunction

// this function expects m to be t1 multiplied with k. this function should be used when multiplication
// is being done separately, outside this butterfly function.
function Vector#(2, ComplexSample) bfly2_epilog(ComplexSample t0, ComplexSample m);
    Vector#(2, ComplexSample) z = newVector();
    z[0] = t0 + m;
    z[1] = t0 - m;

    return z;
endfunction

// Perform a single stage of the FFT, consisting of butterflys and a single
// permutation.
// We pass the table of twiddles as an argument so we can look those up
// dynamically if need be.
function Vector#(FFT_POINTS, ComplexSample) stage_ft(TwiddleTable twiddles, Bit#(TLog#(FFT_LOG_POINTS)) stage, Vector#(FFT_POINTS, ComplexSample) stage_in);
    Vector#(FFT_POINTS, ComplexSample) stage_temp = newVector();
    for(Integer i = 0; i < (valueof(FFT_POINTS)/2); i = i+1) begin
        Integer idx = i * 2;
        let twid = twiddles[stage][i];
        let y = bfly2(takeAt(idx, stage_in), twid);

        stage_temp[idx]   = y[0];
        stage_temp[idx+1] = y[1];
    end

    Vector#(FFT_POINTS, ComplexSample) stage_out = newVector();
    for (Integer i = 0; i < valueof(FFT_POINTS); i = i+1) begin
        stage_out[i] = stage_temp[permute(i, valueof(FFT_POINTS))];
    end
    return stage_out;
endfunction

module mkCombinationalFFT (FFT);

  // Statically generate the twiddle factors table.
  TwiddleTable twiddles = genTwiddles();

  // Define the stage_f function which uses the generated twiddles.
  function Vector#(FFT_POINTS, ComplexSample) stage_f(Bit#(TLog#(FFT_LOG_POINTS)) stage, Vector#(FFT_POINTS, ComplexSample) stage_in);
      return stage_ft(twiddles, stage, stage_in);
  endfunction

  Reg#(Vector#(FFT_POINTS, ComplexSample)) inputREG  <- mkReg(unpack(0));
  Reg#(Vector#(FFT_POINTS, ComplexSample)) outputREG <- mkReg(unpack(0));

  // This rule performs fft using a big mass of combinational logic.
  rule comb_fft;

    Vector#(TAdd#(1, FFT_LOG_POINTS), Vector#(FFT_POINTS, ComplexSample)) stage_data = newVector();
    stage_data[0] = inputREG;
    // inputFIFO.deq();

    for(Integer stage = 0; stage < valueof(FFT_LOG_POINTS); stage=stage+1) begin
        stage_data[stage+1] = stage_f(fromInteger(stage), stage_data[stage]);
    end

    // outputFIFO.enq(stage_data[valueof(FFT_LOG_POINTS)]);
    outputREG <= stage_data[valueof(FFT_LOG_POINTS)];
  endrule

  interface Put request;
    method Action put(Vector#(FFT_POINTS, ComplexSample) x);
        inputREG <= bitReverse(x);
    endmethod
  endinterface

  interface Get response = toGet(outputREG);

endmodule

module mkPipelinedFFT (FFT);

  // Statically generate the twiddle factors table.
  TwiddleTable twiddles = genTwiddles();

  // Define the stage_f function which uses the generated twiddles.
  function Vector#(FFT_POINTS, ComplexSample) stage_f(Bit#(TLog#(FFT_LOG_POINTS)) stage, Vector#(FFT_POINTS, ComplexSample) stage_in);
      return stage_ft(twiddles, stage, stage_in);
  endfunction

  Reg#(Vector#(FFT_POINTS, ComplexSample)) inputREG  <- mkReg(unpack(0));
  Reg#(Vector#(FFT_POINTS, ComplexSample)) isb1  <- mkReg(unpack(0));
  Reg#(Vector#(FFT_POINTS, ComplexSample)) isb2  <- mkReg(unpack(0));
  Reg#(Vector#(FFT_POINTS, ComplexSample)) outputREG <- mkReg(unpack(0));

  // rule for the first stage
  rule stage1;
    Vector#(TAdd#(1, FFT_LOG_POINTS), Vector#(FFT_POINTS, ComplexSample)) stage_data = newVector();
    stage_data[0] = inputREG;
    stage_data[1] = stage_f(0, stage_data[0]);
    isb1._write(stage_data[1]);
  endrule

  rule stage2;
    Vector#(TAdd#(1, FFT_LOG_POINTS), Vector#(FFT_POINTS, ComplexSample)) stage_data = newVector();
    stage_data[1] = isb1;
    stage_data[2] = stage_f(1, stage_data[1]);
    isb2._write(stage_data[2]);
  endrule

  // rule for last stage
  rule stage3;
    Vector#(TAdd#(1, FFT_LOG_POINTS), Vector#(FFT_POINTS, ComplexSample)) stage_data = newVector();
    stage_data[2] = isb2;
    stage_data[3] = stage_f(2, stage_data[2]);
    outputREG._write(stage_data[valueof(FFT_LOG_POINTS)]);
  endrule

  interface Put request;
    method Action put(Vector#(FFT_POINTS, ComplexSample) x);
        inputREG._write(bitReverse(x));
    endmethod
  endinterface

  interface Get response = toGet(outputREG);

endmodule

module mkFoldedFFT (FFT);

    // Statically generate the twiddle factors table.
    TwiddleTable twiddles = genTwiddles();

    // Define the stage_f function which uses the generated twiddles.
    function Vector#(FFT_POINTS, ComplexSample) stage_f(Bit#(TLog#(FFT_LOG_POINTS)) stage, Vector#(FFT_POINTS, ComplexSample) stage_in);
        return stage_ft(twiddles, stage, stage_in);
    endfunction

    Reg#(Vector#(FFT_POINTS, ComplexSample)) theREG  <- mkRegularReg(unpack(0));

    Reg#(Bit#(TLog#(FFT_LOG_POINTS))) stage_counter <- mkRegularReg(0);

    // the user of this module is expected to pick up the output at the right cycle.
    // i could provide a outp_ready method, or a waiting Action, but that would need modifications to the ifc.
    rule the_folded_compute;
        theREG <= stage_f(stage_counter, theREG);
        stage_counter <= stage_counter + 1;
    endrule

    interface Put request;
        method Action put(Vector#(FFT_POINTS, ComplexSample) x) = theREG._write(bitReverse(x));
    endinterface

    interface Get response = toGet(theREG);
endmodule

typedef enum {BFLY, PERMUTE} TraState deriving (Bits, Eq);

// this dude doesn't compile yet. i need to figure out how to play with those Integers without deriving Bits.
module mkSuperFoldedFFT (FFT);

    // Statically generate the twiddle factors table.
    TwiddleTable twiddles = genTwiddles();

    // the reg to hold current state
    Reg#(Vector#(FFT_POINTS, ComplexSample)) theREG  <- mkRegularReg(unpack(0));

    // intra stage counter 1
    Reg#(Bit#(TLog#(TDiv#(FFT_POINTS, 2)))) trasc_1 <- mkRegularReg(0);

    // trasc_1 overflow
    Reg#(Bool) trasc_1_selfloop <- mkRegularReg(False);

    // intra stage counter 2
    Reg#(Bit#(TLog#(FFT_POINTS))) trasc_2 <- mkRegularReg(0);

    // trasc_2 overflow
    Reg#(Bool) trasc_2_selfloop <- mkRegularReg(False);

    // inter stage counter
    Reg#(Bit#(TLog#(FFT_LOG_POINTS))) tersc <- mkRegularReg(0);

    // intra-stage state face reg - starts with a bfly.
    Reg#(TraState) trast <- mkRegularReg(BFLY);

    rule slap_bfly (trast == BFLY && !trasc_1_selfloop);
        // takeables - hardcoded for 8 pts.
        Vector#(FFT_POINTS, ComplexSample) trascratch = theREG;
        Vector#(2, ComplexSample) takeable_0 = takeAt(0, trascratch);
        Vector#(2, ComplexSample) takeable_1 = takeAt(1, trascratch);
        Vector#(2, ComplexSample) takeable_2 = takeAt(2, trascratch);
        Vector#(2, ComplexSample) takeable_3 = takeAt(3, trascratch);
        Vector#(2, ComplexSample) takeable_4 = takeAt(4, trascratch);
        Vector#(2, ComplexSample) takeable_5 = takeAt(5, trascratch);
        Vector#(2, ComplexSample) takeable_6 = takeAt(6, trascratch);
        Vector#(2, ComplexSample) takeable_7 = takeAt(7, trascratch);
        Bit#(TDiv#(CustomTypes::FFT_POINTS, 2)) idx = zeroExtend(trasc_1 * 2);
        let twid = twiddles[tersc][trasc_1];

        let y = case (idx) matches
            0: return bfly2(takeable_0, twid);
            1: return bfly2(takeable_1, twid);
            2: return bfly2(takeable_2, twid);
            3: return bfly2(takeable_3, twid);
            4: return bfly2(takeable_4, twid);
            5: return bfly2(takeable_5, twid);
            6: return bfly2(takeable_6, twid);
            7: return bfly2(takeable_7, twid);
        endcase;

        trascratch[idx] = y[0];
        trascratch[idx+1] = y[1];
        theREG <= trascratch;
        trasc_1 <= trasc_1 + 1;
        if (trasc_1 == fromInteger(valueOf(FFT_POINTS)/2 - 1)) begin
            trasc_1_selfloop <= True;
        end
    endrule

    rule zapp_bfly (trast == BFLY && trasc_1_selfloop);
        trasc_1_selfloop <= False;
        trast <= PERMUTE;
    endrule

    for (Integer i = 0 ; i < valueOf(FFT_POINTS) ; i = i + 1) begin
    rule confuse_reader (trast == PERMUTE && trasc_2 == fromInteger(i) && !trasc_2_selfloop);
        // don't get confused. im just permuting here.
        Vector#(FFT_POINTS, ComplexSample) trascratch = theREG;
        trascratch[trasc_2] = trascratch[permute(i, valueOf(FFT_POINTS))];
        theREG <= trascratch;
        trasc_2 <= trasc_2 + 1;
        if (trasc_2 == fromInteger(valueOf(FFT_POINTS) - 1)) begin
            trasc_2_selfloop <= True;
        end
    endrule
    end

    rule zapp_trasc_2 (trast == PERMUTE && trasc_2_selfloop);
        trast <= BFLY;
        tersc <= tersc + 1;
    endrule

    // takes fft inputs
    interface Put request;
        method Action put(Vector#(FFT_POINTS, ComplexSample) x) = theREG._write(bitReverse(x));
    endinterface

    // gives fft outputs
    interface Get response = toGet(theREG);

endmodule: mkSuperFoldedFFT


// Wrapper around The FFT module we actually want to use
module mkFFT (FFT);
    // FFT fft <- mkCombinationalFFT();
    // FFT fft <- mkPipelinedFFT();
    // FFT fft <- mkFoldedFFT();
    FFT fft <- mkSuperFoldedFFT();

    interface Put request = fft.request;
    interface Get response = fft.response;
endmodule