import Vector::*;
import ClientServer::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import RegFile::*;
import DReg::*;
import BRAM::*;
import MathUtils::*;

import Types::*;

typedef 8 NodeNum;
typedef TLog#(NodeNum) NodeIdWidth;

typedef 2  GROUP_SIZE;          // 二叉树结构
typedef 3  TreeDepth;        // log2(1024)=10
typedef TDiv#(NodeNum, GROUP_SIZE) GROUP_NUM;
typedef enum { ArbBegin, Arb1, ArbEnd, ArbProcess } ArbState deriving (Bits, Eq);

interface ArbiterIFC;
    interface Vector#(NodeNum, PhySrv)  phyRxMetaSrv;  // 连接所有节点的phyTxMetaClt
    interface Vector#(NodeNum, PhyClt)  phyTxMetaClt;  // 连接所有节点的phyRxMetaSrv
endinterface

(* synthesize *)
module mkArbiter(ArbiterIFC);
    // 接口FIFO -----------------------------------------------------------
    Vector#(NodeNum, FIFOF#(PhyEvent))     txReqQs  <- replicateM(mkFIFOF);
    Vector#(NodeNum, FIFOF#(GenericResp))  txRespQs <- replicateM(mkFIFOF);
    Vector#(NodeNum, FIFOF#(PhyEvent))     rxReqQs  <- replicateM(mkSizedFIFOF(10));
    Vector#(NodeNum, FIFOF#(GenericResp))  rxRespQs <- replicateM(mkSizedFIFOF(10));

    // 广播流水线寄存器 -----------------------------------------------------
    Vector#(TreeDepth, Vector#(TDiv#(NodeNum, TExp#(1)), 
    Reg#(Tuple2#(Bool, PhyEvent)))) broadcastRegs <- replicateM(replicateM(mkDReg(tuple2(False,getEmptyPhyEvent))));


    // 仲裁流水线寄存器-----------------------------------------------------
    Reg#(ArbState) arbState <- mkReg(ArbBegin);

    Vector#(TDiv#(NodeNum, TExp#(1)), Reg#(PhyId)) grantIdRegs1 <- replicateM(mkReg(0));
    Vector#(TDiv#(NodeNum, TExp#(1)), Reg#(Bool))  validRegs1   <- replicateM(mkReg(False));
    rule arbitrateLevel0 (arbState == ArbBegin);
        PhyId groups = fromInteger(valueOf(NodeNum))/2;
        for (PhyId g = 0; g < groups; g = g + 1) begin
            PhyId node0 = 2*g;
            PhyId node1 = 2*g+1;
            Bool req0 = txReqQs[node0].notEmpty;
            Bool req1 = txReqQs[node1].notEmpty;
            grantIdRegs1[g] <= (req0 ? node0 : (req1 ? node1 : 0));
            validRegs1[g]   <= req0 || req1;
        end
        // 切换到下一阶段
        arbState <= Arb1;
    endrule


    Vector#(TDiv#(NodeNum, TExp#(2)), Reg#(PhyId)) grantIdRegs2 <- replicateM(mkReg(0));
    Vector#(TDiv#(NodeNum, TExp#(2)), Reg#(Bool))  validRegs2   <- replicateM(mkReg(False));
    rule arbitrateLevel1 (arbState == Arb1);
        PhyId groups = fromInteger(valueOf(NodeNum)/(2**2));
        for (PhyId g = 0; g < groups; g = g + 1) begin
            PhyId child0 = 2*g;
            PhyId child1 = 2*g+1;
            
            Bool valid0 = validRegs1[child0];
            Bool valid1 = validRegs1[child1];
            
            // 优先选择左子树（低ID区域）
            grantIdRegs2[g] <= (valid0 ? grantIdRegs1[child0] : (valid1 ? grantIdRegs1[child1] : 0));
            validRegs2[g] <= valid0 || valid1;
        end
        arbState <= ArbEnd;
    endrule


    Vector#(TDiv#(NodeNum, TExp#(3)), Reg#(PhyId)) grantIdRegs3 <- replicateM(mkReg(0));
    Vector#(TDiv#(NodeNum, TExp#(3)), Reg#(Bool))  validRegs3   <- replicateM(mkReg(False));
    rule arbitrateLevel2 (arbState == ArbEnd);
        Bool valid0 = validRegs2[0];
        Bool valid1 = validRegs2[1];
        Bool valid  = valid0 || valid1;
        PhyId grantId = valid0 ? grantIdRegs2[0] : (valid1 ? grantIdRegs2[1] : 0);
        
        // 优先选择左子树（低ID区域）
        grantIdRegs3[0] <= grantId;
        validRegs3[0] <= valid;

        if(valid)begin
            arbState <= ArbProcess;
        end else begin
            arbState <= ArbBegin;
        end
    endrule

    // 最终仲裁结果处理 -----------------------------------------------------
    rule processFinalGrant(arbState == ArbProcess);
        PhyId grantId  = (grantIdRegs3[0]);
        Bool  grantValid = validRegs3[0];
        let phyTxReq = txReqQs[grantId].first;
        // 启动广播流水线
        broadcastRegs[0][0] <= tuple2(grantValid, phyTxReq);
        txReqQs[grantId].deq;
        txRespQs[grantId].enq(GenericResp{});
        arbState <= ArbBegin;
        $display("grant %0d",grantId);
    endrule


    // 树状广播流水线 ------------------------------------------------------
    rule propagateBroadcast0;  // 非最终级
        for(Integer lv=0; lv<valueOf(TreeDepth)-1; lv=lv+1) begin
            Integer groups = (2**lv);
            for(Integer g=0; g<groups; g=g+1) begin
                let {valid, phyTxReq} = broadcastRegs[lv][g];
                
                // 计算子组范围
                Integer child0 = 2*g;
                Integer child1 = 2*g+1;
                
                // 向两个子组广播
                broadcastRegs[lv+1][child0] <=  tuple2(valid, phyTxReq);
                broadcastRegs[lv+1][child1] <=  tuple2(valid, phyTxReq);
            end
        end
    endrule

    // 最终级广播处理 ------------------------------------------------------
    rule finalBroadcast;
        Integer groups = valueOf(NodeNum)/2;
        for(Integer g=0; g<groups; g=g+1) begin
            let {valid, phyTxReq} = broadcastRegs[valueOf(TreeDepth)-1][g];
            
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