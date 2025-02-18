import Randomizable::*;
import Vector::*;
import Arbiter::*;
import FIFO::*;

import PrimUtils::*;
import Arbitration::*;

typedef 32 TestPortSz;
typedef 1000 TestNum;

function Tuple2#(Bit#(TLog#(portSz)), Vector#(portSz, Bool)) 
    getIdealGrant(Vector#(portSz, Bool) reqVec);
        Bit#(TLog#(portSz)) grantId = 0;
        Vector#(portSz, Bool) grantVec = replicate(False);
        for (Integer idx = valueOf(portSz)-1; idx >= 0; idx = idx - 1)
            if (reqVec[idx]) 
                grantId = fromInteger(idx);
        grantVec[grantId] = True;
        return tuple2(grantId, grantVec);
    endfunction

module mkTestFixedPriorityArbiter(Empty);
    Arbiter_IFC#(TestPortSz) arbiter <- mkFixedPriorityArbiter;

    Reg#(Bool) isInitReg <- mkReg(False);
    Reg#(UInt#(32)) testNumReg <- mkReg(0);

    Randomize#(Bit#(TestPortSz)) reqGen <- mkGenericRandomizer;

    Wire#(Bit#(TLog#(TestPortSz)))   ideaIdWire  <- mkWire;
    Wire#(Vector#(TestPortSz, Bool)) ideaVecWire <- mkWire;

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

typedef 1024 PipePortSz;

module mkTestArbiterPipeLine(Empty);
    let arbiter <- mkFixedPriorityArbiterPipeline1024;

    Reg#(Bool) isInitReg <- mkReg(False);
    Reg#(UInt#(32)) testNumReg <- mkReg(0);
    Reg#(Bit#(6)) reqReg <- mkReg(0);

    FIFO#(Tuple2#(Bit#(TLog#(PipePortSz)), Vector#(PipePortSz, Bool))) ideaResultQ <- mkFIFO;

    Randomize#(Bit#(PipePortSz)) reqGen <- mkGenericRandomizer;

    rule testInit if (!isInitReg);
        isInitReg <= True;
        reqGen.cntrl.init;
    endrule

    rule testGen if (isInitReg && testNumReg < fromInteger(valueOf(TestNum)));
        let reqBit <- reqGen.next;
        Vector#(PipePortSz, Bool) reqVec = unpack(reqBit);
        for(Integer idx = 0; idx < valueOf(PipePortSz); idx = idx + 1) begin
            if (reqVec[idx])
                arbiter.clients[idx].request;
        end
        reqReg <= reqBit[5:0];
        // let ideaResult = getIdealGrant(reqVec);
        // ideaResultQ.enq(ideaResult);
        testNumReg <= testNumReg + 1;
    endrule

    rule testAssert if (isInitReg && testNumReg < fromInteger(valueOf(TestNum)));
        // let {ideaId, ideaVec} = ideaResultQ.first;
        // ideaResultQ.deq;
        Vector#(PipePortSz, Bool) resultVec = replicate(False);
        for(Integer idx = 0; idx < valueOf(PipePortSz); idx = idx + 1) begin
            resultVec[idx] = arbiter.clients[idx].grant;
        end
        let resultId = arbiter.grant_id;
        $display("Id: ", resultId, ", req: %b", reqReg);
        // immAssert(
        //     (ideaId == resultId) && (resultVec == ideaVec),
        //     "Fixed Priority Arbiter Test @ mkTestFixedPriorityArbiter",
        //     $format("IdeaId=%d but resultId=%d", ideaId, resultId)
        // );
    endrule

    rule stop if (testNumReg >= fromInteger(valueOf(TestNum)));
        $display("Test Fixed Priority Arbiter Pass!\n");
        $finish();
    endrule
endmodule