
import GetPut::*;
import Connectable::*;
import ClientServer::*;

import Types::*;
import MacCore::*;
import CsmaUtils::*;
import PrimUtils::*;

typedef 200 PacketCountMax;

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

module mkTestMacMultiComm(Empty);

    Reg#(MpduLen) sendCount <- mkReg(1);            // 发送次数控制
    Reg#(UInt#(8)) receiveCount <- mkReg(1);        // 接收次数控制
    Reg#(Bool) isInitReg <- mkReg(False);

    MacCore dut0 <- mkMacDCF(0);
    MacCore dut1 <- mkMacDCF(1);

    mkConnection(dut0.lowMacTxClt, dut1.lowMacRxSrv);  // dut0发送 -> dut1接收
    mkConnection(dut1.lowMacTxClt, dut0.lowMacRxSrv);  // dut1发送 -> dut0接收

    Reg#(PhyStatus) phyStatusReg <- mkReg(PhyStatus{cca: False, fcsCorrect: True});

    rule updatePhyStatus;
        dut0.phyStatus.put(phyStatusReg);
        dut1.phyStatus.put(phyStatusReg);
    endrule

    rule handshake0;
        let resp <- dut0.highMacTxSrv.response.get;
    endrule

    rule send if (sendCount <= fromInteger(valueOf(PacketCountMax)));
        if(sendCount <= fromInteger(valueOf(PacketCountMax))) begin
            let txReq = getEmptyMacEvent;
            txReq.srcMacId = 0;
            txReq.dstMacId = 1;
            txReq.mpduDigest.frameType = fromInteger(valueOf(FC_TYPE_DATA));
            //txReq.mpduDigest.length = 2048;
            txReq.mpduDigest.length = sendCount * 512; //使长度变化，用于每次打印出不同的rxReq
            dut0.highMacTxSrv.request.put(txReq);
            sendCount <= sendCount + 1;
            immLog("mkTestMacMultiComm", "send", $format("dut0 put a data to the txQueue!"));
            $display("=== dut0发送第%0d次 ===",sendCount);
        end
    endrule

    rule receive;
        let rxReq <- dut1.highMacRxClt.request.get;
        receiveCount <= receiveCount + 1;
        $display(rxReq);
        $display("=== dut1接收第%0d次 ===",receiveCount);
        if(receiveCount == fromInteger(valueOf(PacketCountMax))) begin
            $display("=== %0d次发包仿真完成 ===",fromInteger(valueOf(PacketCountMax)));
            $finish();
        end
    endrule

endmodule