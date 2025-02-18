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

import GetPut::*;

import Types::*;

interface MacCore;
    interface MacTxSrv highMacTxSrv;
    interface MacRxClt highMacRxClt;

    interface MacRxSrv lowMacRxSrv;
    interface MacTxClt lowMacTxClt;

    interface MacCfgSrv configSrv;
endinterface

// A Fake MAC without any access control
module mkMacPipe#(Integer id)(MacCore);
    FIFO#(MacTxReq)  highMacTxReqQ  <- mkFIFO;
    FIFO#(MacTxResp) highMacTxRespQ <- mkFIFO;
    FIFO#(MacRxReq)  highMacRxReqQ  <- mkFIFO;
    FIFO#(MacRxResp) highMacRxRespQ <- mkFIFO;

    FIFO#(MacTxReq)  lowMacTxReqQ   <- mkFIFO;
    FIFO#(MacTxResp) lowMacTxRespQ  <- mkFIFO;
    FIFO#(MacRxReq)  lowMacRxReqQ   <- mkFIFO;
    FIFO#(MacRxResp) lowMacRxRespQ  <- mkFIFO;

    FIFO#(MacCfgReq)  configReqQ    <- mkFIFO;
    FIFO#(MacCfgResp) configRespQ   <- mkFIFO;

    Reg#(MacConfig)  macCfgReg      <- mkRegU;
    Reg#(MacStatus)  macStaReg      <- mkRegU;

    rule forwardTx;
        let txReq = highMacTxReqQ.first;
        highMacTxReqQ.deq;
        highMacTxRespQ.enq(MacTxResp {})
        lowMacTxReqQ.enq(txReq);
    endrule

    rule handshakeTx;
        lowMacTxRespQ.deq;
    endrule

    rule forwardRx;
        let rxReq = lowMacRxReqQ.first;
        lowMacRxReqQ.deq;
        if (macCfgReg.filterEn && rxReq.dstId == fromInteger(id)) begin
            highMacRxReqQ.enq(rxReq);
        end
    endrule

    rule handshakeRx;
        highMacRxRespQ.deq;
    endrule

    rule setCfg;
        macCfgReg <= configReqQ.first;
        configReqQ.deq;
        configRespQ.enq(macStaReg);
    endrule

    interface highMacTxSrv = toGPServer(highMacTxReqQ, highMacTxRespQ);
    interface highMacRxClt = toGPClient(highMacRxReqQ, highMacRxRespQ);
    interface lowMacTxClt  = toGPClient(lowMacTxReqQ, lowMacTxRespQ);
    interface lowMacRxSrv  = toGPServer(lowMacRxReqQ, lowMacRxRespQ);
    
    interface configSrv    = toGPServer(configReqQ, configRespQ);
endmodule

// 802.11 DCF Low Mac Layer
module mkMacCsma#(Integer id)(MacCore);
    FIFO#(MacTxReq)  highMacTxReqQ  <- mkFIFO;
    FIFO#(MacTxResp) highMacTxRespQ <- mkFIFO;
    FIFO#(MacRxReq)  highMacRxReqQ  <- mkFIFO;
    FIFO#(MacRxResp) highMacRxRespQ <- mkFIFO;

    FIFO#(MacTxReq)  lowMacTxReqQ   <- mkFIFO;
    FIFO#(MacTxResp) lowMacTxRespQ  <- mkFIFO;
    FIFO#(MacRxReq)  lowMacRxReqQ   <- mkFIFO;
    FIFO#(MacRxResp) lowMacRxRespQ  <- mkFIFO;

    Reg#(MacConfig)  macCfgReg      <- mkRegU;

    interface highMacTxSrv = toGPServer(highMacTxReqQ, highMacTxRespQ);

endmodule