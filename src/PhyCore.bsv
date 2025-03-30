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
    interface MacSrv lowMacTxSrv;
    interface MacClt lowMacRxClt;

    interface PhySrv phyRxSrv;
    interface PhyClt phyTxClt;

    interface PhyCfgSrv configSrv;
endinterface

(* synthesize *)
module mkPhyYansWifi#(Integer id)(PhyCore);
    FIFO#(MacEvent)    lowMacTxReqQ   <- mkFIFO;
    FIFO#(GenericResp) lowMacTxRespQ  <- mkFIFO;
    FIFO#(MacEvent)    lowMacRxReqQ   <- mkFIFO;
    FIFO#(GenericResp) lowMacRxRespQ  <- mkFIFO;

    FIFO#(PhyEvent)    phyTxReqQ      <- mkFIFO;
    FIFO#(GenericResp) phyTxRespQ     <- mkFIFO;
    FIFO#(PhyEvent)    phyRxReqQ      <- mkFIFO;
    FIFO#(GenericResp) phyRxRespQ     <- mkFIFO;



    interface lowMacTxSrv = toGPServer(lowMacRxReqQ, lowMacRxRespQ);
    interface lowMacRxClt = toGPClient(lowMacTxReqQ, lowMacTxRespQ);

    interface phyTxClt    = toGPClient(phyTxReqQ, phyTxRespQ);
    interface phyRxSrv    = toGPServer(phyRxReqQ, phyRxRespQ);

endmodule
