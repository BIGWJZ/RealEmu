import GetPut::*;
import Connectable::*;
import ClientServer::*;
import Vector::*;
import FIFO::*;
import MathUtils::*;


import Types::*;
import Arbitration::*;
import Channel::*;

typedef 8 NodeNum;
typedef 3 TreeDepth;

module mkTestArbiter(Empty);
    //实例化仲裁器
    ArbiterIFC arbiter <- mkArbiter;
    
    //创建节点模型
    Vector#(NodeNum, GainLossModel) nodes <- replicateM(mkGainLossModelIdeal());
    
    //连接接口
    for(Integer i = 0; i < valueOf(NodeNum); i = i + 1) begin
        mkConnection(nodes[i].phyTxMetaClt, arbiter.phyRxMetaSrv[i]);
        mkConnection(arbiter.phyTxMetaClt[i], nodes[i].phyRxMetaSrv);
    end

    Reg#(UInt#(64)) cycleCount <- mkReg(0);

    rule updateclock;
        cycleCount <= cycleCount + 1;
    endrule

    // 测试案例1：基础仲裁
    rule send1 if (cycleCount == 100);
        $display("node0 1 tx");
        PhyEvent event0 = getEmptyPhyEvent();
        event0.srcPhyId = 0;
        PhyEvent event1 = getEmptyPhyEvent();
        event1.srcPhyId = 1;
        nodes[0].phyTxSrv.request.put(event0);
        nodes[1].phyTxSrv.request.put(event1);
    endrule

    rule send2 if (cycleCount == 200);
        $display("node2 tx");
        PhyEvent event2 = getEmptyPhyEvent();
        event2.srcPhyId = 2;
        nodes[2].phyTxSrv.request.put(event2);
    endrule

    rule send3 if (cycleCount == 500);
        $display("all node tx");
        Vector#(NodeNum, PhyEvent) events = replicate(getEmptyPhyEvent());
        for(Integer j=0; j<valueOf(NodeNum); j=j+1) begin
            events[j].srcPhyId = fromInteger(j);
            nodes[j].phyTxSrv.request.put(events[j]);
        end
    endrule

    rule simEnd if(cycleCount == 1000);
        $display("Test end");
        $finish;
    endrule


    rule rx7;//node  7
        let received <- nodes[7].phyRxClt.request.get;
        $display("node7 receive from node%0d",received.srcPhyId);
    endrule
endmodule