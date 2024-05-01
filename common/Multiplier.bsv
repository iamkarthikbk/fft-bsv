import Counter::*;
import FIFO::*;
import FixedPoint::*;
import CustomReg::*;
import CustomTypes::*;
`include "fft.defines"

// the reason for keeping two methods instead of one is to allow pipelining lkater without a hassle of changing the interface.
interface Multiplier; 
    method Action putOperands(ComplexSample op1, ComplexSample op2);
    method ComplexSample getResult;
endinterface

(* synthesize *)
module mkMultiplier (Multiplier);

    Wire#(ComplexSample) wr_answer <- mkDWire(unpack(0));

    method Action putOperands(ComplexSample op1, ComplexSample op2);
        // this  overloaded * operator will belong to the complex typeclass provided by bsv.
        wr_answer <= op1 * op2;
    endmethod
    method ComplexSample getResult = wr_answer;

endmodule