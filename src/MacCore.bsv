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
module mkMacPipe(MacCore);
    FIFO#(MacTxReq)  highMacTxReqQ  <- mkFIFO;
    FIFO#(MacTxResp) highMacTxRespQ <- mkFIFO;
    FIFO#(MacRxReq)  highMacRxReqQ  <- mkFIFO;
    FIFO#(MacRxResp) highMacRxRespQ <- mkFIFO;

    FIFO#(MacTxReq)  lowMacTxReqQ   <- mkFIFO;
    FIFO#(MacTxResp) lowMacTxRespQ  <- mkFIFO;
    FIFO#(MacRxReq)  lowMacRxReqQ   <- mkFIFO;
    FIFO#(MacRxResp) lowMacRxRespQ  <- mkFIFO;

    Reg#(MacConfig)  macCfgReg      <- mkRegU;

    rule forwardTx;
        
    endrule

endmodule

// 802.11 DCF Low Mac Layer
module mkMacCsma(MacCore);
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