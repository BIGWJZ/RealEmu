
import GetPut::*;
import Connectable::*;
import ClientServer::*;
import BRAM::*;
import ROM::*;
import Vector::*;

import Types::*;
import MacCore::*;
import PhyCore::*;
import CsmaUtils::*;
import PrimUtils::*;
//import Channel::*;

// 组装一个节点的示例，仅供参考未运行
module mkTestOneNode(Empty);
    // 多节点测试请声明一个Node接口组装，并用for循环例化多个节点
    let mac0 <- mkMacDCF(0);
    let phy0 <- mkPhyYansWifi;

    let mac1 <- mkMacDCF(1);
    let phy1 <- mkPhyYansWifi;

    mkConnection(mac0.lowMacTxClt, phy0.lowMacTxSrv);
    mkConnection(mac0.lowMacRxSrv, phy0.lowMacRxClt);

    mkConnection(mac1.lowMacTxClt, phy1.lowMacTxSrv);
    mkConnection(mac1.lowMacRxSrv, phy1.lowMacRxClt);

    // 删除信道相关代码，暂时直接连接PHY层接口
    mkConnection(phy0.phyTxClt, phy1.phyRxSrv);  // phy0发送→phy1接收
    mkConnection(phy1.phyTxClt, phy0.phyRxSrv);  // phy1发送→phy0接收

    /*
    // 多节点测试时需要使用包含仲裁器和多路选择器的Channel模块，此处仅使用LogLoss模块

    BRAM2Port#(ChBramAddr, NodeDistance) distanceRam2 <- mkBRAM2Server(
        BRAM_Configure {                            
            memorySize   : 0,                       
            loadFormat   : tagged Hex "bram_one.txt",     
            latency      : 2,                          
            outFIFODepth : 4,                          
            allowWriteResponseBypass : False           
        }
    );

    let channel01 <- mkGainLossModelLogDistance(distanceRam2);
    let channel10 <- mkGainLossModelLogDistance(distanceRam2);

    mkConnection(phy0.phyTxClt, channel01.phyTxMetaSrv);
    mkConnection(phy1.phyRxSrv, channel01.phyRxMetaClt);

    mkConnection(phy1.phyTxClt, channel10.phyTxMetaSrv);
    mkConnection(phy0.phyRxSrv, channel10.phyRxMetaClt);
    */

    // 请添加测试rule
    rule updatePhyStatus;
        // 获取 PhyCore 的 CCA 状态
        Bool cca0 = phy0.getCcaStatus;
        Bool cca1 = phy1.getCcaStatus;

        PhyStatus phyStatusReg0 = PhyStatus{cca: cca0, fcsCorrect: True};
        PhyStatus phyStatusReg1 = PhyStatus{cca: cca1, fcsCorrect: True};

        mac0.phyStatus.put(phyStatusReg0);
        mac1.phyStatus.put(phyStatusReg1);
    endrule

    rule handshake0;
        let resp <- mac0.highMacTxSrv.response.get;
    endrule

    Reg#(Bool) testInitReg <- mkReg(False); //测试一次

    rule send if (!testInitReg);
        let txReq = getDefaultMacEvent;
        txReq.srcMacId = 0;
        txReq.dstMacId = 1;
        txReq.mpduDigest.frameType = fromInteger(valueOf(FC_TYPE_DATA));
        txReq.mpduDigest.length = 2048;
        mac0.highMacTxSrv.request.put(txReq);
        immLog("mkTestMacSimpleOnce", "send", $format("mac0 put a data to the txQueue!"));
        testInitReg <= True;
    endrule

    rule receive;
        let rxReq <- mac1.highMacRxClt.request.get;
        $display(rxReq);
        $display("Test Pass");
        $finish();
    endrule

endmodule
