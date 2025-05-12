//1024 32一层
import Vector::*;
import ClientServer::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import RegFile::*;
import DReg::*;
import MathUtils::*;

import Types::*;

typedef 1024 NodeNum;
typedef 32   GROUP_SIZE;  // 每个父节点32个子节点
typedef TLog#(NodeNum) NodeIdWidth;  // 10 bits
typedef TDiv#(TLog#(NodeNum), TLog#(GROUP_SIZE)) TreeDepth;  // log32(1024)=2

typedef enum {MuxBegin, MuxEnd} MuxState deriving (Bits, Eq);

interface PollIFC;
    interface Vector#(NodeNum, PhySrv)  phyRxMetaSrv;  // 连接所有节点的phyTxMetaClt
    interface Vector#(NodeNum, PhyClt)  phyTxMetaClt;  // 连接所有节点的phyRxMetaSrv
endinterface

(* synthesize *)
module mkPoll(PollIFC);
    ///////////////////////////////////////////////////////////////////////////
    // 接口FIFO
    ///////////////////////////////////////////////////////////////////////////
    Vector#(NodeNum, FIFOF#(PhyEvent))     txReqQs  <- replicateM(mkGFIFOF1(False, True));        // 保护压入，不保护弹出
    Vector#(NodeNum, FIFOF#(GenericResp))  txRespQs <- replicateM(mkFIFOF);
    Vector#(NodeNum, FIFOF#(PhyEvent))     rxReqQs  <- replicateM(mkSizedFIFOF(10));
    Vector#(NodeNum, FIFOF#(GenericResp))  rxRespQs <- replicateM(mkSizedFIFOF(10));

    ///////////////////////////////////////////////////////////////////////////
    // 轮询控制逻辑（保持原始结构）
    ///////////////////////////////////////////////////////////////////////////
    Reg#(Bool) pollValidReg <- mkReg(True);
    Reg#(UInt#(NodeIdWidth)) pollIdReg <- mkReg(0);
    Vector#(NodeNum, Reg#(Bool)) grandValidRegs <- replicateM(mkDReg(False));
    Vector#(NodeNum, Reg#(PhyEvent)) txEventRegs <- replicateM(mkDReg(getEmptyPhyEvent));
    Vector#(TreeDepth, Vector#(TDiv#(NodeNum, GROUP_SIZE), 
    Reg#(Tuple2#(Bool, PhyEvent)))) deMuxRegs <- replicateM(replicateM(mkDReg(tuple2(False, getEmptyPhyEvent))));

  
    rule poll if (pollValidReg);
        let current_id = pollIdReg;
        if (txReqQs[current_id].notEmpty) begin
            let phyTxReq = txReqQs[current_id].first;
            txReqQs[current_id].deq;
            grandValidRegs[current_id] <= True;
            txEventRegs[current_id] <= phyTxReq;
            pollValidReg <= False;
        end
        pollIdReg <= current_id == fromInteger(valueOf(NodeNum)-1) ? 0 : current_id + 1;
    endrule

    ///////////////////////////////////////////////////////////////////////////
    // 32叉树聚合逻辑
    ///////////////////////////////////////////////////////////////////////////
    Reg#(MuxState) muxState <- mkReg(MuxBegin);
    Vector#(TDiv#(NodeNum, GROUP_SIZE), Reg#(Bool))     validRegs1 <- replicateM(mkReg(False));
    Vector#(TDiv#(NodeNum, GROUP_SIZE), Reg#(PhyEvent)) eventRegs1 <- replicateM(mkReg(getEmptyPhyEvent));
    Reg#(Bool)     validRegs2 <- mkReg(False);
    Reg#(PhyEvent) eventRegs2 <- mkReg(getEmptyPhyEvent);

    // Level 1 MUX（32节点→1节点）
    rule muxLevel0 if (muxState == MuxBegin && !pollValidReg);
        for (Integer g = 0; g < valueOf(TDiv#(NodeNum, GROUP_SIZE)); g = g + 1) begin
            Bool group_valid = False;
            PhyEvent group_event = getEmptyPhyEvent;
            
            // 扫描32个子节点
            for (Integer i = 0; i < valueOf(GROUP_SIZE); i = i + 1) begin
                let node_id = g * valueOf(GROUP_SIZE) + i;
                if (grandValidRegs[node_id]) begin
                    group_valid = True;
                    group_event = txEventRegs[node_id];  // 取最后一个有效事件
                end
            end
            
            validRegs1[g] <= group_valid;
            eventRegs1[g] <= group_event;
        end
        muxState <= MuxEnd;
    endrule

    // Level 2 MUX（32组→1个全局）
    (* mutually_exclusive = "poll, muxEnd" *)  
    rule muxEnd if (muxState == MuxEnd);
        Bool final_valid = False;
        PhyEvent final_event = getEmptyPhyEvent;
        
        for (Integer g = 0; g < valueOf(TDiv#(NodeNum, GROUP_SIZE)); g = g + 1) begin
            if (validRegs1[g]) begin
                final_valid = True;
                final_event = eventRegs1[g];  // 取最后一个有效事件
            end
        end
        
        validRegs2 <= final_valid;
        eventRegs2 <= final_event;
        deMuxRegs[0][0] <= tuple2(validRegs2, eventRegs2);
        muxState <= MuxBegin;
        pollValidReg <= True;
    endrule

    ///////////////////////////////////////////////////////////////////////////
    // 32叉树广播流水线
    ///////////////////////////////////////////////////////////////////////////

    rule propagateDeMux;
        for (Integer lv = 0; lv < valueOf(TreeDepth)-1; lv = lv + 1) begin
            Integer next_lv = lv + 1;
            Integer gr = valueOf(GROUP_SIZE) ** fromInteger(lv);
            for (Integer g = 0; g < gr; g = g + 1) begin
                let {valid, txEvent} = deMuxRegs[lv][g];
                // 每个节点广播到32个子节点
                for (Integer sg = 0; sg < valueOf(GROUP_SIZE); sg = sg + 1) begin
                    deMuxRegs[next_lv][g*valueOf(GROUP_SIZE)+sg] <= tuple2(valid, txEvent);
                end
            end
        end
    endrule

    ///////////////////////////////////////////////////////////////////////////
    // 最终广播分发
    ///////////////////////////////////////////////////////////////////////////
    rule finalBroadcast;
        for (Integer g = 0; g < valueOf(NodeNum); g = g + 1) begin
            let {valid, txEvent} = deMuxRegs[valueOf(TreeDepth)-1][g / valueOf(GROUP_SIZE)];
            if (valid && (txEvent.srcPhyId != fromInteger(g))) begin
                rxReqQs[g].enq(txEvent);
            end
        end
    endrule

    ///////////////////////////////////////////////////////////////////////////
    // 接口连接
    ///////////////////////////////////////////////////////////////////////////
    Vector#(NodeNum, PhySrv) rxMetaSrv;
    Vector#(NodeNum, PhyClt) txMetaClt;
    
    for (Integer i = 0; i < valueOf(NodeNum); i = i + 1) begin
        rxMetaSrv[i] = toGPServer(txReqQs[i], txRespQs[i]);
        txMetaClt[i] = toGPClient(rxReqQs[i], rxRespQs[i]);
    end

    interface phyRxMetaSrv = rxMetaSrv;
    interface phyTxMetaClt = txMetaClt;
endmodule




////////////////////////////////////////////////////////////////////
//1024节点，4叉树结构
///////////////////////////////////////////////////////////////////
// import Vector::*;
// import ClientServer::*;
// import GetPut::*;
// import FIFO::*;
// import FIFOF::*;
// import RegFile::*;
// import DReg::*;
// import MathUtils::*;

// import Types::*;

// typedef 1024 NodeNum;
// typedef 4    GROUP_SIZE;  // 4叉树结构
// typedef TLog#(NodeNum) NodeIdWidth;  // 10 bits
// typedef 5 TreeDepth;  // log4(1024)=5

// // 增强状态机定义
// typedef enum {
//     Polling,        // 轮询状态
//     Aggregate1,     // 第1级聚合（1024→256）
//     Aggregate2,     // 第2级聚合（256→64）
//     Aggregate3,     // 第3级聚合（64→16）
//     Aggregate4,     // 第4级聚合（16→4）
//     Aggregate5,     // 第5级聚合（4→1）
// } MuxState deriving (Bits, Eq, FShow);

// interface PollIFC;
//     interface Vector#(NodeNum, PhySrv)  phyRxMetaSrv;
//     interface Vector#(NodeNum, PhyClt)  phyTxMetaClt;
//     method Bool isProcessing();
// endinterface

// (* synthesize *)
// module mkPoll(PollIFC);
//     ///////////////////////////////////////////////////////////////////////////
//     // 接口FIFO
//     ///////////////////////////////////////////////////////////////////////////
//     Vector#(NodeNum, FIFOF#(PhyEvent))     txReqQs  <- replicateM(mkGFIFOF1(False, True));        // 保护压入，不保护弹出
//     Vector#(NodeNum, FIFOF#(GenericResp))  txRespQs <- replicateM(mkFIFOF);
//     Vector#(NodeNum, FIFOF#(PhyEvent))     rxReqQs  <- replicateM(mkSizedFIFOF(10));
//     Vector#(NodeNum, FIFOF#(GenericResp))  rxRespQs <- replicateM(mkSizedFIFOF(10));

//     // 控制寄存器
//     Reg#(MuxState) muxState <- mkReg(Polling);
//     Reg#(UInt#(NodeIdWidth)) pollId <- mkReg(0);
    
//     // 分层事件寄存器
//     Vector#(TreeDepth, Vector#(TDiv#(NodeNum, GROUP_SIZE), 
//         Reg#(Maybe#(PhyEvent)))) aggRegs <- replicateM(replicateM(mkReg(tagged Invalid)));

//     Vector#(TreeDepth, Vector#(TDiv#(NodeNum, GROUP_SIZE), 
//     Reg#(Tuple2#(Bool, PhyEvent)))) deMuxRegs <- replicateM(replicateM(mkDReg(tuple2(False, getEmptyPhyEvent))));

//     // 轮询规则（优先级最高）
//     (* preempts = "do_poll, aggregate_*" *)
//     rule do_poll if (muxState == Polling);
//         if (txReqQs[pollId].notEmpty) begin
//             let evt = txReqQs[pollId].first;
//             txReqQs[pollId].deq;
//             aggRegs[0][pollId] <= tagged Valid evt;
//             muxState <= Aggregate1;
//         end
//         pollId <= (pollId == fromInteger(valueOf(NodeNum)-1)) ? 0 : pollId + 1;
//     endrule

//     // 分层聚合规则 ----------------------------------------------------------
//     // 第1级聚合（4→1）
//     rule aggregate_1 if (muxState == Aggregate1);
//         for(Integer g=0; g<256; g=g+1) begin  // 1024/4=256组
//             Maybe#(PhyEvent) evt = tagged Invalid;
//             for(Integer i=0; i<4; i=i+1) begin
//                 if (isValid(aggRegs[0][g*4+i])) begin
//                     evt = aggRegs[0][g*4+i];
//                 end
//             end
//             aggRegs[1][g] <= evt;
//         end
//         muxState <= Aggregate2;
//     endrule

//     // 第2级聚合（256→64）
//     rule aggregate_2 if (muxState == Aggregate2);
//         for(Integer g=0; g<64; g=g+1) begin
//             Maybe#(PhyEvent) evt = tagged Invalid;
//             for(Integer i=0; i<4; i=i+1) begin
//                 if (isValid(aggRegs[1][g*4+i])) evt = aggRegs[1][g*4+i];
//             end
//             aggRegs[2][g] <= evt;
//         end
//         muxState <= Aggregate3;
//     endrule

//     // 第3级聚合（64→16）
//     rule aggregate_3 if (muxState == Aggregate3);
//         for(Integer g=0; g<16; g=g+1) begin
//             Maybe#(PhyEvent) evt = tagged Invalid;
//             for(Integer i=0; i<4; i=i+1) begin
//                 if (isValid(aggRegs[2][g*4+i])) evt = aggRegs[2][g*4+i];
//             end
//             aggRegs[3][g] <= evt;
//         end
//         muxState <= Aggregate4;
//     endrule

//     // 第4级聚合（16→4）
//     rule aggregate_4 if (muxState == Aggregate4);
//         for(Integer g=0; g<4; g=g+1) begin
//             Maybe#(PhyEvent) evt = tagged Invalid;
//             for(Integer i=0; i<4; i=i+1) begin
//                 if (isValid(aggRegs[3][g*4+i])) evt = aggRegs[3][g*4+i];
//             end
//             aggRegs[4][g] <= evt;
//         end
//         muxState <= Aggregate5;
//     endrule

//     // 第5级聚合（4→1）
//     rule aggregate_5 if (muxState == Aggregate5);
//         Maybe#(PhyEvent) finalEvt = tagged Invalid;
//         for(Integer g=0; g<4; g=g+1) begin
//             if (isValid(aggRegs[4][g])) finalEvt = aggRegs[4][g];
//         end
//         deMuxRegs[0][0] <= finalEvt;
//         muxState <=  Polling;
//     endrule


//     // 分层广播规则 ----------------------------------------------------------
//     // 第1级广播（1→4）
//     rule propagateDeMux;
//         for (Integer lv = 0; lv < valueOf(TreeDepth)-1; lv = lv + 1) begin
//             Integer next_lv = lv + 1;
//             Integer gr = valueOf(GROUP_SIZE) ** fromInteger(lv);
//             for (Integer g = 0; g < gr; g = g + 1) begin
//                 let {valid, txEvent} = deMuxRegs[lv][g];
//                 for (Integer sg = 0; sg < valueOf(GROUP_SIZE); sg = sg + 1) begin
//                     deMuxRegs[next_lv][g*valueOf(GROUP_SIZE)+sg] <= tuple2(valid, txEvent);
//                 end
//             end
//         end
//     endrule

//     ///////////////////////////////////////////////////////////////////////////
//     // 最终广播分发
//     ///////////////////////////////////////////////////////////////////////////
//     rule finalBroadcast;
//         for (Integer g = 0; g < valueOf(NodeNum); g = g + 1) begin
//             let {valid, txEvent} = deMuxRegs[valueOf(TreeDepth)-1][g / valueOf(GROUP_SIZE)];
//             if (valid && (txEvent.srcPhyId != fromInteger(g))) begin
//                 rxReqQs[g].enq(txEvent);
//             end
//         end
//     endrule


//     // 接口连接
//     Vector#(NodeNum, PhySrv) rxSrv;
//     Vector#(NodeNum, PhyClt) txClt;
//     for(Integer i=0; i<valueOf(NodeNum); i=i+1) begin
//         rxSrv[i] = toGPServer(txReqQs[i], txRespQs[i]);
//         txClt[i] = toGPClient(rxReqQs[i], rxRespQs[i]);
//     end

//     interface phyRxMetaSrv = rxSrv;
//     interface phyTxMetaClt = txClt;
// endmodule