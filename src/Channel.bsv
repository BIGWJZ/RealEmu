// Copyright (C) 2025 Jingzhi Wang
// Email: jzwang@smail.nju.edu.cn
//
// This file is part of RealEmu.
//
// RealEmu is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// RealEmu is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with RealEmu.  If not, see <https://www.gnu.org/licenses/>.


import ClientServer::*;
import RegFile::*;
import Vector::*;
import FIFO::*;
import BRAM::*;

import Types::*;
import MathUtils::*;
import ROM::*;

// Single path channel model
interface GainLossModel;
    interface PhyTxSrv phyTxMetaSrv;
    interface PhyRxClt phyRxMetaClt;
endinterface

// Ideal Channel without any gain loss
(* synthesize *)
module mkGainLossModelIdeal(GainLossModel);
    FIFO#(PhyTxReq)  txReqQ  <- mkFIFO;
    FIFO#(PhyTxResp) txRespQ <- mkFIFO;
    FIFO#(PhyRxReq)  rxReqQ  <- mkFIFO;
    FIFO#(PhyRxResp) rxRespQ <- mkFIFO;

    // forward the meta directly, do not modify power
    rule forward;
        rxReqQ.enq(txReqQ.first);
        txReqQ.deq;
        txRespQ.enq(PhyTxResp{});
    endrule

    rule handshake;
        rxRespQ.deq;
    endrule

    interface phyTxMetaSrv = toGPServer(txReqQ, txRespQ);
    interface phyRxMetaClt = toGPClient(rxReqQ, rxRespQ);
endmodule


typedef Bit#(TMul#(2, DEV_ID_WIDTH)) ChBramAddr;

function ChBramAddr genChBramAddr(PhyId id0, PhyId id1);
    return (zeroExtend(id0) << (valueOf(DEV_ID_WIDTH))) & zeroExtend(id1);
endfunction

typedef 5 FSModelPipeDepth;

/* LogDistance Channel, gain loss ~ 20log(distance) between nodes
 * L = L0 + 10nlog((d)/(d0)), where d0 is set as 1m, n = 2 for free space case
 * L0 and d0 are read from system register block
 */
module mkGainLossModelLogDistance#(
    BRAM2Port#(ChBramAddr, NodeDistance) distanceRam2
    // RegBlock regBlock                                   
)(GainLossModel);
    FIFO#(PhyTxReq)  txReqQ  <- mkFIFO;
    FIFO#(PhyTxResp) txRespQ <- mkFIFO;
    FIFO#(PhyRxReq)  rxReqQ  <- mkFIFO;
    FIFO#(PhyRxResp) rxRespQ <- mkFIFO;

    FIFO#(PhyTxReq)     txPipeQ   <- mkSizedFIFO(valueOf(FSModelPipeDepth));
    FIFO#(NodeDistance) distPipeQ <- mkSizedFIFO(valueOf(FSModelPipeDepth));  

    MathTable lossTable <- mkLogDistanceGainLossTable;

    // ram的外部定义，需要暴露另一端口给DMA配置
    // BRAM2Port#(ChBramAddr, NodeDistance) distanceRam2 <- mkBRAM2Server(
    //     BRAM_Configure {                            
    //         memorySize   : 0,                       
    //         loadFormat   : tagged Hex "../scripts/bram_one.txt",     
    //         latency      : 2,                          
    //         outFIFODepth : 4,                          
    //         allowWriteResponseBypass : False           
    //     }
    // );

    // 外部配置接口
    // rule updateParam;
    //     param <= regBlock.logDistanceChannelParam.get;
    // endrule

    rule queryDistance;
        let phyTxReq = txReqQ.first;
        let txPower = phyTxReq.rfParam.power;
        txReqQ.deq;
        txRespQ.enq(PhyTxResp{});
        txPipeQ.enq(phyTxReq);
        let bramReq = BRAMRequest{             
            write: False,          
            responseOnWrite: False,  
            address: genChBramAddr(phyTxReq.srcId, phyTxReq.dstId),            
            datain: 0             
        };
        distanceRam2.portB.request.put(bramReq);
        // $display("Generate Bram Req! Addr: ", bramReq.address);
    endrule

    rule queryLoss;
        let phyTxReq = txPipeQ.first;
        let distance <- distanceRam2.portB.response.get;
        lossTable.request.put(unpack(distance));
        // $display("Get Distance, ", distance);
    endrule

    rule getLoss;
        // L = L0 + 10nlog(d/d0), where d0 = 1, n = 2
        // GainLoss = (1 << SHIFT) * 20log(d) = 256 * (0~96.33dB)
        let loss <- lossTable.response.get;  
        // $display("Get Loss, ", loss);
        let phyTxReq = txPipeQ.first;
        txPipeQ.deq;
        let txPower = phyTxReq.rfParam.power;
        let rxPower = txPower - unpack(pack(loss));  // power is signed, loss is unsigned
        phyTxReq.rfParam.power = rxPower;
        rxReqQ.enq(phyTxReq);
    endrule

    rule handshakeRx;
        rxRespQ.deq;
    endrule

    interface phyTxMetaSrv = toGPServer(txReqQ, txRespQ);
    interface phyRxMetaClt = toGPClient(rxReqQ, rxRespQ);
endmodule


interface ChannelModel;
    interface Vector#(MAX_DEV_NUM, PhyTxSrv) phyTxSrvVec;
    interface Vector#(MAX_DEV_NUM, PhyRxClt) phyRxCltVec;
endinterface

// TODO: channel 
// module mkChannelFreeSpace(ChannelModel);

//     let arbiter <- mkFixedPriorityArbiterPipeline1024;
//     MuxPipe#(MAX_DEV_NUM)   mux     <- mkMuxPipeline1024;

//     rule getArbitResult;
//         let grantId = arbiter.grantId;
//         mux.grantId.put
//     endrule


// endmodule

