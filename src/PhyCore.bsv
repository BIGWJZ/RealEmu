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

interface PhyCore;
    interface MacTxSrv lowMacTxSrv;
    interface MacRxClt lowMacRxClt;

    interface PhyRxSrv phyRxSrv;
    interface PhyTxSrv phyTxClt;

    interface PhyCfgSrv configSrv;
endinterface

module mkPhy11A(PhyCore);
    FIFO#(MacTxReq)  lowMacTxReqQ   <- mkFIFO;
    FIFO#(MacTxResp) lowMacTxRespQ  <- mkFIFO;
    FIFO#(MacRxReq)  lowMacRxReqQ   <- mkFIFO;
    FIFO#(MacRxResp) lowMacRxRespQ  <- mkFIFO;

    FIFO#(PhyTxReq)  phyTxReqQ      <- mkFIFO;
    FIFO#(PhyTxResp) phyTxRespQ     <- mkFIFO;
    FIFO#(PhyRxReq)  phyRxReqQ      <- mkFIFO;
    FIFO#(PhyRxResp) phyRxRespQ     <- mkFIFO;



    interface lowMacTxSrv = toGPServer(lowMacRxReqQ, lowMacRxRespQ);
    interface lowMacRxClt = toGPClient(lowMacTxReqQ, lowMacTxRespQ);

    interface phyTxClt    = toGPClient(phyTxReqQ, phyTxRespQ);
    interface phyRxSrv    = toGPServer(phyRxReqQ, phyRxRespQ);

endmodule


module mkPhy11B(PhyCore);

endmodule


module mkPhy11N(PhyCore);

endmodule

module mkPhy11AX(PhyCore);

endmodule