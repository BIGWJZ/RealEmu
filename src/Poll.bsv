import Vector::*;
import ClientServer::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import RegFile::*;
import DReg::*;
import MathUtils::*;

import Types::*;

typedef 8 NodeNum;
typedef TLog#(NodeNum) NodeIdWidth;

typedef 2  GROUP_SIZE;          // 二叉树结构
typedef 3  TreeDepth;        // log2(1024)=10
typedef enum {MuxBegin, MuxLevel1, MuxEnd} MuxState deriving (Bits, Eq);

interface PollIFC;
    interface Vector#(NodeNum, PhySrv)  phyRxMetaSrv;  // 连接所有节点的phyTxMetaClt
    interface Vector#(NodeNum, PhyClt)  phyTxMetaClt;  // 连接所有节点的phyRxMetaSrv
endinterface

(* synthesize *)
module mkPoll(PollIFC);
    // 接口FIFO -----------------------------------------------------------
    Vector#(NodeNum, FIFOF#(PhyEvent))     txReqQs  <- replicateM(mkGFIFOF1(False, True));        // 保护压入，不保护弹出
    Vector#(NodeNum, FIFOF#(GenericResp))  txRespQs <- replicateM(mkFIFOF);
    Vector#(NodeNum, FIFOF#(PhyEvent))     rxReqQs  <- replicateM(mkSizedFIFOF(10));
    Vector#(NodeNum, FIFOF#(GenericResp))  rxRespQs <- replicateM(mkSizedFIFOF(10));


    //poll
    Reg#(Bool)  pollValidReg  <- mkReg(True);
    Reg#(UInt#(NodeIdWidth)) pollIdReg <- mkReg(0);
    Vector#(NodeNum, Reg#(Bool)) grandValidRegs <- replicateM(mkDReg(False));
    Vector#(NodeNum, Reg#(PhyEvent)) txEventRegs <- replicateM(mkDReg(getEmptyPhyEvent));

    
    rule poll if (pollValidReg);
        let current_id = pollIdReg;
        if (txReqQs[current_id].notEmpty) begin
            let phyTxReq = txReqQs[current_id].first;
            txReqQs[current_id].deq;
            grandValidRegs[current_id] <= True;
            txEventRegs[current_id] <= phyTxReq;
            pollValidReg <= False;
        end
        pollIdReg <= (current_id == fromInteger(valueOf(NodeNum)-1))? 0 : current_id + 1;
    endrule

    //MUX
    Reg#(MuxState) muxState <- mkReg(MuxBegin);
    Vector#(TDiv#(NodeNum, TExp#(1)), Reg#(Bool))     validRegs1   <- replicateM(mkReg(False));
    Vector#(TDiv#(NodeNum, TExp#(1)), Reg#(PhyEvent)) eventRegs1   <- replicateM(mkReg(getEmptyPhyEvent));

    rule muxLevel0 if((muxState == MuxBegin) && (pollValidReg == False));
        PhyId groups = fromInteger(valueOf(NodeNum))/2;
        for (PhyId g = 0; g < groups; g = g + 1) begin
            PhyId node0 = 2*g; PhyId node1 = 2*g+1;
            validRegs1[g] <=  grandValidRegs[node0] || grandValidRegs[node1];
            eventRegs1[g] <= (grandValidRegs[node0] ? txEventRegs[node0] : (grandValidRegs[node1] ? txEventRegs[node1] : getEmptyPhyEvent));
        end
        // 切换到下一阶段
        muxState <= MuxLevel1;
    endrule


    Vector#(TDiv#(NodeNum, TExp#(2)), Reg#(Bool))     validRegs2   <- replicateM(mkReg(False));
    Vector#(TDiv#(NodeNum, TExp#(2)), Reg#(PhyEvent)) eventRegs2   <- replicateM(mkReg(getEmptyPhyEvent));

    rule muxLevel1 if(muxState == MuxLevel1);
        PhyId groups = fromInteger(valueOf(NodeNum))/4;
        for (PhyId g = 0; g < groups; g = g + 1) begin
            PhyId node0 = 2*g; PhyId node1 = 2*g+1;
            validRegs2[g] <=  validRegs1[node0] || validRegs1[node1];
            eventRegs2[g] <= (validRegs1[node0] ? eventRegs1[node0] : (validRegs1[node1] ? eventRegs1[node1] : getEmptyPhyEvent));
        end
        // 切换到下一阶段
        muxState <= MuxEnd;
    endrule

    Vector#(TreeDepth, Vector#(TDiv#(NodeNum, TExp#(1)), 
    Reg#(Tuple2#(Bool, PhyEvent)))) deMuxRegs <- replicateM(replicateM(mkDReg(tuple2(False,getEmptyPhyEvent))));

    rule muxLevel2 if((muxState == MuxEnd) && (pollValidReg == False));
        let validReg       =  validRegs2[0] || validRegs2[1];
        let grandEventReg  = (validRegs2[0] ? eventRegs2[0] : (validRegs2[1] ? eventRegs2[1] : getEmptyPhyEvent));
        //启动广播流水线
        deMuxRegs[0][0] <= tuple2(validReg, grandEventReg);
        muxState <= MuxBegin;
        pollValidReg <= True;
    endrule


    // 树状广播流水线 ------------------------------------------------------
    rule propagatedeMux0;  // 非最终级
        for(Integer lv=0; lv<valueOf(TreeDepth)-1; lv=lv+1) begin
            Integer groups = (2**lv);
            for(Integer g=0; g<groups; g=g+1) begin
                let {valid, phyTxReq} = deMuxRegs[lv][g];
                
                // 计算子组范围
                Integer child0 = 2*g;
                Integer child1 = 2*g+1;
                
                // 向两个子组广播
                deMuxRegs[lv+1][child0] <=  tuple2(valid, phyTxReq);
                deMuxRegs[lv+1][child1] <=  tuple2(valid, phyTxReq);
            end
        end
    endrule

    // 最终级广播处理 ------------------------------------------------------
    rule finaldeMux;
        Integer groups = valueOf(NodeNum)/2;
        for(Integer g=0; g<groups; g=g+1) begin
            let {valid, phyTxReq} = deMuxRegs[valueOf(TreeDepth)-1][g];
            
            // 计算目标节点
            Integer node0 = 2*g;
            Integer node1 = 2*g+1;
            
            // 写入接收队列（跳过源节点）
            if(valid)begin
                if(phyTxReq.srcPhyId != fromInteger(node0)) 
                    rxReqQs[node0].enq(phyTxReq);
                if(phyTxReq.srcPhyId != fromInteger(node1)) 
                    rxReqQs[node1].enq(phyTxReq);
            end
        end
    endrule

    // 接口连接 -----------------------------------------------------------
    Vector#(NodeNum, PhySrv) rxMetaSrv;
    Vector#(NodeNum, PhyClt) txMetaClt;
    
    for(Integer i=0; i<valueOf(NodeNum); i=i+1) begin
        rxMetaSrv[i] = toGPServer(txReqQs[i], txRespQs[i]);
        txMetaClt[i] = toGPClient(rxReqQs[i], rxRespQs[i]);
    end

    interface phyRxMetaSrv = rxMetaSrv;
    interface phyTxMetaClt = txMetaClt;
endmodule



