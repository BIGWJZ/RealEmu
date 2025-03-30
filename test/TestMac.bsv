
import GetPut::*;
import Connectable::*;
import ClientServer::*;

import Types::*;
import MacCore::*;
import CsmaUtils::*;
import PrimUtils::*;

// 最简单的一次发包情况
module mkTestMacSimpleOnce(Empty);

    Reg#(Bool) isInitReg <- mkReg(False);

    MacCore dut0 <- mkMacDCF(0);
    MacCore dut1 <- mkMacDCF(1);

    mkConnection(dut0.lowMacTxClt, dut1.lowMacRxSrv);  // dut0发送 -> dut1接收
    mkConnection(dut1.lowMacTxClt, dut0.lowMacRxSrv);  // dut1发送 -> dut0接收

    Reg#(PhyStatus) phyStatusReg <- mkReg(PhyStatus{cca: False, fcsCorrect: True});

    Reg#(UInt#(32)) cycleCount <- mkReg(0);

    Reg#(Bool) testInitReg <- mkReg(False);


    rule updateclock;
        cycleCount <= cycleCount + 1;
    endrule

    rule updatePhyStatus;
        dut0.phyStatus.put(phyStatusReg);
        dut1.phyStatus.put(phyStatusReg);
    endrule

    rule handshake0;
        let resp <- dut0.highMacTxSrv.response.get;
    endrule

    rule send if (!testInitReg);
        let txReq = getEmptyMacEvent;
        txReq.srcMacId = 0;
        txReq.dstMacId = 1;
        txReq.mpduDigest.frameType = fromInteger(valueOf(FC_TYPE_DATA));
        txReq.mpduDigest.length = 2048;
        dut0.highMacTxSrv.request.put(txReq);
        immLog("mkTestMacSimpleOnce", "send", $format("dut0 put a data to the txQueue!"));
        testInitReg <= True;
    endrule

    rule receive;
        let rxReq <- dut1.highMacRxClt.request.get;
        $display(rxReq);
        $display("Test Pass");
        $finish();
    endrule

endmodule