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

import Vector::*;
import GetPut::*;
import Arbiter::*;

function Tuple3#(Vector#(portSz, Bool), Bit#(TLog#(portSz)), Bool)
runFixedPriorityArbitration(Vector#(portSz, Bool) reqWireVec);
    Vector#(portSz, Bool) grantVec = replicate(False);
    Bit#(TLog#(portSz))   grantId  = 0;
    Bool found = False;

    // find the grant_vector, warning it is a combinational logic
    // so keep portSz not too big
    for (Integer idx = 0; idx < valueOf(portSz); idx = idx + 1) begin
        let isReq = reqWireVec[idx];
        if (!found && isReq) begin
            grantVec[idx] = True;
            grantId       = fromInteger(idx);
            found         = True;
        end
    end

    return tuple3(grantVec, grantId, found);
endfunction

function Bool readPulseWire (PulseWire pw);
    return  pw._read;
endfunction


module mkFixedPriorityArbiter(Arbiter_IFC#(portSz));
    Wire#(Vector#(portSz, Bool))  grantVecWire   <- mkBypassWire;
    Wire#(Bit#(TLog#(portSz)))    grantIdWire    <- mkBypassWire;
    Vector#(portSz, PulseWire)    reqWireVec     <- replicateM(mkPulseWire);
    
    rule every;
        let {grantVec, grantId, found} = runFixedPriorityArbitration(map(readPulseWire, reqWireVec));
        grantVecWire  <= grantVec;
        grantIdWire   <= grantId;
    endrule

    Vector#(portSz, ArbiterClient_IFC) clientVec = newVector;
    for (Integer clientIdx = 0; clientIdx < valueOf(portSz); clientIdx = clientIdx + 1)

        clientVec[clientIdx] = (interface ArbiterClient_IFC

            method Action request();
                reqWireVec[clientIdx].send();
            endmethod

            method Action lock();
                // dummyAction;
            endmethod

            method grant ();
                return grantVecWire[clientIdx];
            endmethod

            endinterface);

    interface clients = clientVec;
    method    grant_id = grantIdWire;
endmodule


typedef 1024 ClientNum;
typedef 32 ARB_MAX_PORT;
typedef TDiv#(ClientNum, ARB_MAX_PORT) ArbiterNum;

module mkFixedPriorityArbiterPipeline1024(Arbiter_IFC#(ClientNum));
    Wire#(Vector#(ClientNum, Bool))  grantVecWire   <- mkBypassWire;
    Wire#(Bit#(TLog#(ClientNum)))    grantIdWire    <- mkBypassWire;

    Vector#(ClientNum, PulseWire) reqWireVec        <- replicateM(mkPulseWire);

    Reg#(Vector#(ArbiterNum, Bool))                       treeReqVecReg   <- mkReg(replicate(False));
    Reg#(Vector#(ArbiterNum, Bit#(TLog#(ArbiterNum))))    treeGrantIdReg  <- mkReg(replicate(0));
    Reg#(Bit#(ClientNum))                                 treeGrantVecReg <- mkReg(0);

    rule arbitTree;
        Vector#(ArbiterNum, Bool) treeReqVec = replicate(False);
        Vector#(ArbiterNum, Bit#(ARB_MAX_PORT)) treeGrantVec = replicate(0);
        Vector#(ArbiterNum, Bit#(TLog#(ArbiterNum))) treeGrantIdVec = replicate(0);
        for (Integer arbitIdx = 0; arbitIdx < valueOf(ArbiterNum); arbitIdx = arbitIdx + 1) begin
            Vector#(ARB_MAX_PORT, PulseWire) reqVec = takeAt(arbitIdx, reqWireVec);
            Vector#(ARB_MAX_PORT, Bool) reqs = map(readPulseWire, reqVec);
            let {grantVec, grantId, found} = runFixedPriorityArbitration(reqs);
            treeReqVec[arbitIdx] = found;
            treeGrantVec[arbitIdx] = pack(grantVec);
            treeGrantIdVec[arbitIdx] = grantId;
        end
        treeReqVecReg   <= treeReqVec;
        treeGrantVecReg <= pack(treeGrantVec);
        treeGrantIdReg  <= treeGrantIdVec;
    endrule

    rule arbitLeaf;
        let {grantVec, grantId, found} = runFixedPriorityArbitration(treeReqVecReg);
        grantIdWire <= {grantId, treeGrantIdReg[grantId]};
        Vector#(ClientNum, Bool) resultVec = replicate(False);
        for (Integer clientIdx = 0; clientIdx < valueOf(ClientNum); clientIdx = clientIdx + 1) begin
            let arbitIdx = clientIdx / valueOf(ARB_MAX_PORT);
            resultVec[clientIdx] = grantVec[arbitIdx] && unpack(treeGrantVecReg[clientIdx]);
        end
        grantVecWire <= resultVec;
    endrule

    Vector#(ClientNum, ArbiterClient_IFC) clientVec = newVector;

    for (Integer clientIdx = 0; clientIdx < valueOf(ClientNum); clientIdx = clientIdx + 1) begin

        clientVec[clientIdx] = (interface ArbiterClient_IFC

            method Action request();
                reqWireVec[clientIdx].send;
            endmethod

            method Action lock();
                // dummyAction;
            endmethod

            method grant();
                return grantVecWire[clientIdx];
            endmethod
            
        endinterface);
    end

    interface clients = clientVec;
    method    grant_id = grantIdWire;
endmodule

