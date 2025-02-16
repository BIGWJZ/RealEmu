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

import Types::*;

// Single path channel model
interface GainLossModel;
    interface PhyTxSrv phyTxMetaSrv;
    interface PhyRxClt phyRxMetaClt;
endinterface

// Ideal Channel without any gain loss
(* synthesize *)
module mkGainLossModelIdeal(ChannelModel);
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
    return (zeroExtent(id0) << (valueOf(DEV_ID_WIDTH))) & zeroExtent(id1);
endfunction

// Log gain loss ~ distance between nodes
module mkGainLossModelFreeSpace(ChannelModel);
    FIFO#(PhyTxReq)  txReqQ  <- mkFIFO;
    FIFO#(PhyTxResp) txRespQ <- mkFIFO;
    FIFO#(PhyRxReq)  rxReqQ  <- mkFIFO;
    FIFO#(PhyRxResp) rxRespQ <- mkFIFO;

    // TODO: Add gain loss to the packet, determined by the distance between nodes
    rule process;
        let txPower = txReqQ.first.rfParam.power;
        txReqQ.deq;
        txRespQ.enq(PhyTxResp{});
        // TODO: Generate a BRAM query request to get the `d` according to srcId and dstId
    endrule

    rule calculate;
        // TODO: Calculate Rx Power based on distance and Tx Power
    endrule

    rule handshake;
        rxRespQ.deq;
    endrule

    interface phyTxMetaSrv = toGPServer(txReqQ, txRespQ);
    interface phyRxMetaClt = toGPClient(rxReqQ, rxRespQ);
endmodule

interface ChannelModel;
    Vector#(MAX_DEV_NUM, PhyTxSrv) phyTxSrvVec;
    Vector#(MAX_DEV_NUM, PhyRxClt) phyRxCltVec;
endinterface

