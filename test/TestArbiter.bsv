import Randomizable::*;
import Vector::*;
import Arbiter::*;

import PrimUtils::*;
import Arbitration::*;

typedef 32 TestPortSz;
typedef 1000 TestNum;

module mkTestFixedPriorityArbiter(Empty);
    Arbiter_IFC#(TestPortSz) arbiter <- mkFixedPriorityArbiter;

    Reg#(Bool) isInitReg <- mkReg(False);
    Reg#(UInt#(32)) testNumReg <- mkReg(0);

    Randomize#(Bit#(TestPortSz)) reqGen <- mkGenericRandomizer;

    Wire#(Bit#(TLog#(TestPortSz)))   ideaIdWire  <- mkWire;
    Wire#(Vector#(TestPortSz, Bool)) ideaVecWire <- mkWire;

    function Tuple2#(Bit#(TLog#(TestPortSz)), Vector#(TestPortSz, Bool)) 
    getIdealGrant(Vector#(TestPortSz, Bool) reqVec);
        Bit#(TLog#(TestPortSz)) grantId = 0;
        Vector#(TestPortSz, Bool) grantVec = replicate(False);
        for (Integer idx = valueOf(TestPortSz)-1; idx >= 0; idx = idx - 1)
            if (reqVec[idx]) 
                grantId = fromInteger(idx);
        grantVec[grantId] = True;
        return tuple2(grantId, grantVec);
    endfunction

    rule testInit if (!isInitReg);
        isInitReg <= True;
        reqGen.cntrl.init;
    endrule

    rule testGen if (isInitReg && testNumReg < fromInteger(valueOf(TestNum)));
        let reqBit <- reqGen.next;
        Vector#(TestPortSz, Bool) reqVec = unpack(reqBit);
        for(Integer idx = 0; idx < valueOf(TestPortSz); idx = idx + 1) begin
            if (reqVec[idx])
                arbiter.clients[idx].request;
        end
        let {ideaId, ideaVec} = getIdealGrant(reqVec);
        // $display("ideaId: %d", ideaId);
        // $display("ideaVec: %b", ideaVec);
        ideaIdWire <= ideaId;
        ideaVecWire <= ideaVec;
    endrule

    rule testAssert if (isInitReg && testNumReg < fromInteger(valueOf(TestNum)));
        Vector#(TestPortSz, Bool) resultVec = replicate(False);
        for(Integer idx = 0; idx < valueOf(TestPortSz); idx = idx + 1) begin
            resultVec[idx] = arbiter.clients[idx].grant;
        end
        let resultId = arbiter.grant_id;
        // $display("resultId: %d", resultId);
        // $display("resultVec: %b", resultVec);
        immAssert(
            (ideaIdWire == resultId) && (resultVec == ideaVecWire),
            "Fixed Priority Arbiter Test @ mkTestFixedPriorityArbiter",
            $format("IdeaId=%d but resultId=%d", ideaIdWire, resultId)
        );

        testNumReg <= testNumReg + 1;
    endrule

    rule stop if (testNumReg >= fromInteger(valueOf(TestNum)));
        $display("Test Fixed Priority Arbiter Pass!\n");
        $finish();
    endrule
endmodule



module mkTestArbiterPipeLine(Empty);
    
endmodule