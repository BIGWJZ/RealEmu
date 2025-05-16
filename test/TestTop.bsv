import GetPut::*;
import Connectable::*;
import ClientServer::*;
import Vector::*;

import Types::*;
import MacCore::*;
import CsmaUtils::*;
import PrimUtils::*;
import PhyCore::*;
import Channel::*;
import Poll::*;

typedef 8 NodeNum;             // 总节点数

// 最简单的一次发包情况(无NAV)
module mkTestTop1(Empty);

    // ==================== 节点实例化 ====================
    // 生成MAC核心时同样处理
    Vector#(NodeNum, MacCore) macNodes <- genWithM(compose(mkMacPipe, fromInteger));

    // 生成8个带UInt参数的PHY核心
    Vector#(NodeNum, PhyCore) phyNodes <- genWithM(compose(mkPhyYansWifi, fromInteger));
    
    // 生成信道模型
    Vector#(NodeNum, GainLossModel) channels <- genWithM(compose(mkGainLossModelIdeal, fromInteger));
    
    // 创建轮询控制器
    PollIFC pollController <- mkPoll;

    // ==================== 节点连接 ====================
    // 连接MAC层和PHY层
    for(Integer i=0; i<valueOf(NodeNum); i=i+1) begin
        // MAC层与PHY层连接
        mkConnection(macNodes[i].lowMacTxClt, phyNodes[i].lowMacTxSrv);  // MAC发送->PHY发送
        mkConnection(macNodes[i].lowMacRxSrv, phyNodes[i].lowMacRxClt);  // MAC接收<-PHY接收
        
        // PHY层与信道连接
        mkConnection(phyNodes[i].phyTxClt, channels[i].phyTxSrv);            // PHY发送->信道
        mkConnection(phyNodes[i].phyRxSrv, channels[i].phyRxClt);            // PHY接收<-信道
        
        // 轮询控制器连接
        mkConnection(channels[i].phyTxMetaClt, pollController.phyRxMetaSrv[i]);
        mkConnection(channels[i].phyRxMetaSrv, pollController.phyTxMetaClt[i]);
    end

    Reg#(PhyStatus) phyStatusReg <- mkReg(PhyStatus{cca: False, fcsCorrect: True});
    Reg#(UInt#(32)) cycleCount <- mkReg(0);

    rule updateclock;
        cycleCount <= cycleCount + 1;
    endrule

    rule updatePhyStatus;
        for (Integer i = 0; i < valueof(NodeNum); i = i + 1) begin
            let phyStatus = phyNodes[i].getPhyStatus;
            macNodes[i].phyStatus.put(phyStatus);
        end
    endrule

    for (Integer i = 0; i < valueof(NodeNum); i = i + 1) begin
        rule send if ((cycleCount > fromInteger(i * 100000)) && (i % 2 == 0));
            let txReq = getDefaultMacEvent;
            txReq.srcMacId = fromInteger(i);
            txReq.dstMacId = fromInteger((i + 1) % valueof(NodeNum));
            txReq.mpduDigest.frameType = fromInteger(valueOf(FC_TYPE_DATA));
            txReq.mpduDigest.length = 2048;
            macNodes[i].highMacTxSrv.request.put(txReq);
            immLog("mkTestMultiNode", "send", $format("mac%d put data to txQueue!", i));
        endrule
    end

    // 为每个节点配置接收规则
    for (Integer i = 0; i < valueof(NodeNum); i = i + 1) begin
        rule receive;
            let rxReq <- macNodes[i].highMacRxClt.request.get;
            $display("mac%d Test Pass!", i);
        endrule
    end

endmodule
