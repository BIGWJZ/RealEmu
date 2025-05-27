
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
    let phy0 <- mkPhyYansWifi(0);

    let mac1 <- mkMacDCF(1);
    let phy1 <- mkPhyYansWifi(1);

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
        // 获取 PhyCore 的状态
        let phyStatus0 = phy0.getPhyStatus;
        let phyStatus1 = phy1.getPhyStatus;

        mac0.phyStatus.put(phyStatus0);
        mac1.phyStatus.put(phyStatus1);
    endrule

    rule handshake0;
        let resp <- mac0.highMacTxSrv.response.get;
    endrule

    Reg#(Bool) testInitReg <- mkReg(False); //测试一次

    rule send if (!testInitReg);
        /*
        let txReq = getDefaultMacEvent;
        txReq.srcMacId = 0;
        txReq.dstMacId = 1;
        txReq.mpduDigest.frameType = fromInteger(valueOf(FC_TYPE_DATA));
        txReq.mpduDigest.length = 2048;
        */
        
        Bit#(153) txReqHex = 153'h0000000027c0040002810000000000000000000;
        MacEvent txReq = unpack(txReqHex);
        
        mac0.highMacTxSrv.request.put(txReq);
        $display("txReq (hex): %h", txReq);
        immLog("mkTestMacSimpleOnce", "send", $format("mac0 put a data to the txQueue!"));
        testInitReg <= True;
    endrule

    rule receive;
        let rxReq <- mac1.highMacRxClt.request.get;
        
        $display(rxReq);
        $display(rxReq.srcMacId);
        $display(rxReq.dstMacId);
        $display("Test Pass");
        $finish();
    endrule

endmodule

// 通用节点测试模块（支持任意节点数量）
module mkTestMultiNode2(Empty);
    // 定义节点数量
    Integer numNodes = 4; // 例如4个节点

    // 创建 MAC 和 PHY 模块的向量
    Vector#(4, MacCore) macs <- genWithM(mkMacDCF); 
    Vector#(4, PhyCore) phys <- genWithM(mkPhyYansWifi);

    // 连接 MAC 和 PHY 的 LowMac 接口
    for (Integer i = 0; i < numNodes; i = i + 1) begin
        mkConnection(macs[i].lowMacTxClt, phys[i].lowMacTxSrv);
        mkConnection(macs[i].lowMacRxSrv, phys[i].lowMacRxClt);
    end

    mkConnection(phys[0].phyTxClt, phys[1].phyRxSrv);  // phy0发送→phy1接收
    mkConnection(phys[1].phyTxClt, phys[0].phyRxSrv);  // phy1发送→phy0接收
    mkConnection(phys[2].phyTxClt, phys[3].phyRxSrv);  // phy2发送→phy3接收
    mkConnection(phys[3].phyTxClt, phys[2].phyRxSrv);  // phy3发送→phy2接收

    // 更新所有节点的 PHY 状态
    rule updatePhyStatus;
        for (Integer i = 0; i < numNodes; i = i + 1) begin
            let phyStatus = phys[i].getPhyStatus;
            macs[i].phyStatus.put(phyStatus);
        end
    endrule

    // 测试规则：发送和接收
    Vector#(4, Reg#(Bool)) testInitRegs <- replicateM(mkReg(False));
    Reg#(UInt#(64)) cycleCount <- mkReg(0);

    rule updateClock;
        cycleCount <= cycleCount + 1;
    endrule

    // 为每个节点配置发送规则
    for (Integer i = 0; i < numNodes; i = i + 1) begin
        rule send if (!testInitRegs[i] && (cycleCount > fromInteger(i * 100000)) && (i % 2 == 0));
            let txReq = getDefaultMacEvent;
            txReq.srcMacId = fromInteger(i);
            txReq.dstMacId = fromInteger((i + 1) % numNodes);
            txReq.mpduDigest.frameType = fromInteger(valueOf(FC_TYPE_DATA));
            txReq.mpduDigest.length = 2048;
            macs[i].highMacTxSrv.request.put(txReq);
            immLog("mkTestMultiNode", "send", $format("mac%d put data to txQueue!", i));
            testInitRegs[i] <= True;
        endrule
    end

    // 为每个节点配置接收规则
    for (Integer i = 0; i < numNodes; i = i + 1) begin
        rule receive;
            let rxReq <- macs[i].highMacRxClt.request.get;
            $display("mac%d Test Pass!", i);
        endrule
    end
endmodule