import FIFO::*;
import Randomizable::*;
import GetPut::*;

import ROM::*;

typedef UInt#(16) TbRomAddr;
typedef UInt#(16) TbRomData;

typedef 100 TestNum;

// Just display, without any assert
module mkTestROM(Empty);
    Rom1port#(TbRomAddr, TbRomData) rom <- mkSingleRom("bram_gainloss_512.txt");
    Randomize#(TbRomAddr) addrGen <- mkGenericRandomizer;

    Reg#(Bool)      isInitReg  <- mkReg(False);
    Reg#(UInt#(32)) cntReg     <- mkReg(0);

    FIFO#(TbRomAddr) addrQ     <- mkFIFO;
    
    rule testInit if (!isInitReg);
        isInitReg <= True;
        addrGen.cntrl.init;
    endrule
    
    rule testInput if (isInitReg);
        let addr <- addrGen.next;
        rom.request.put(addr);
        addrQ.enq(addr);
        cntReg <= cntReg + 1;
    endrule

    rule testOutput if (isInitReg);
        let data <- rom.response.get;
        $display("Addr: ", addrQ.first, ", Data: %h", data);
        addrQ.deq;
    endrule

    rule testEnd if (isInitReg && cntReg >= fromInteger(valueOf(TestNum)));
        $finish();
    endrule
endmodule