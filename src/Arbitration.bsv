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
            grantId       = fromInteger(x);
            found         = True;
        end
    end

    return tuple3(grantVec, grantId, found);
endfunction


module mkFixedPriorityArbiter(Arbiter_IFC#(portSz));
    Wire#(Vector#(portSz, Bool))  grantVecWire   <- mkBypassWire;
    Wire#(Bit#(TLog#(portSz)))    grantIdWire    <- mkBypassWire;
    Vector#(portSz, PulseWire)    reqWireVec     <- replicateM(mkPulseWire);
    
    rule every;
        let {grantVec, grantId, found} = runFixedPriorityArbitration(reqWireVec)
    
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
                dummyAction;
            endmethod

            method grant ();
                return grantVecWire[clientIdx];
            endmethod

            endinterface);

    interface clients = clientVec;
    method    grant_id = grantIdWire;
endmodule

typedef 32 ARB_MAX_PORT;

module mkFixedPriorityArbiterPipeline1024(Arbiter_IFC#(portSz));
    Wire#(Vector#(portSz, Bool))  grantVecWire   <- mkBypassWire;
    Wire#(Bit#(TLog#(portSz)))    grantIdWire    <- mkBypassWire;

    Integer arbitSz = valueOf(TDiv#(portSz, ARB_MAX_PORT));

    Vector#(arbitSz, Vector#(ARB_MAX_PORT, PulseWire)) reqWireVecVec <- replicateM(replicateM(mkPulseWire));
    Reg#(Vector#(arbitSz, Bool)) treeReqVecReg <- mkReg(replicate(False));
    Reg#(Vector#(portSz, Bool))  grantVecReg   <- mkReg#(replicate(False));

    rule arbitTree;
        Vector#(arbitSz, Bool) treeReqVec = replicate(False);
        Bit#(portSz) treeGrant
        for (Integer arbitIdx = 0; arbitIdx < arbitSz; arbitIdx = arbitIdx + 1);
            let {grantVec, grantId, found} = runFixedPriorityArbitration(reqWireVecVec[arbitIdx]);
            treeReqVec[arbitIdx] = found;
        treeReqVecReg <= treeReqVec;
    endrule

    rule arbitLeaf;
        let {grantVec, grantId, found} = runFixedPriorityArbitration(treeReqVecReg);
        for (Integer clientIdx = 0; clientIdx < valueOf(portSz); clientIdx = clientIdx + 1) begin
            
        end

    endrule

    Vector#(portSz, ArbiterClient_IFC) clientVec = newVector;

    for (Integer clientIdx = 0; clientIdx < valueOf(portSz); clientIdx = clientIdx + 1) begin

        let arbitIdx = clientIdx / valueOf(portSz);
        let localIdx = clientIdx % valueOf(portSz);

        clientVec[clientIdx] = (interface ArbiterClient_IFC

            method Action request();
                reqWireVecVec[arbitIdx].clients[localIdx].request;
            endmethod

            method Action lock();
                dummyAction;
            endmethod

            method grant();
                grantVecWire[clientIdx]
            
        )
    end

endmodule



/*
 *  Different with a single Arbiter, the ArbitDemux1024 is coupled with data plane
 *  when conduncting arbitration. ArbitDemux1024 consumes less latency than using a
 *  seperated Arbit and Demux, which choosing the data refered to the grant value.
*/
interface ArbitDemuxClt#(type tData);
    method Action request(tData);
    method Bool   grant();
endinterface

interface ArbitDemux#(numeric type portSz, type tData);
    interface Vector#(portSz, ArbitDemuxClt#(tData))    clients;
    interface Get#(Tuple2#(Bit#(TLog#(portSz)), tData)) result;
endinterface
module mkFixedPriorityArbiterDemux#(
    ArbitDemux#(numeric type portSz, type tData)
) provisos(
    Bits#(tData, dataSz),
    Add#(1, anySz, portSz)
);
    
    Wire#(Vector#(portSz, Bool))  grantVecWire   <- mkBypassWire;
    Wire#(Bit#(TLog#(portSz)))    grantIdWire    <- mkBypassWire;
    Reg#(Bit#(TLog#(portSz)))     grantIdReg     <- mkRegU;
    Reg#(Tuple2#(Bit#(TLog#(portSz)), tData)) resultTp <- mkFIFO;

    Vector#(portSz, PulseWire)    reqWireVec     <- replicateM(mkPulseWire);
    Vector#(portSz, Reg#(tData))  dataRegVec     <- replicateM(mkWire)
    
    rule arbiter;
        Vector#(portSz, Bool) grantVec = replicate(False);
        Bit#(TLog#(portSz))   grantId  = 0;
        Bool found = False;

        // find the grant_vector, warning it is a combinational logic
        // so keep portSz not too big
        for (Integer idx = 0; idx < valueOf(portSz); idx = idx + 1) begin
            let isReq = reqWireVec[idx];
            if (!found && isReq && resultQ.notFull) begin
                grantVec[idx] = True;
                grantId       = fromInteger(idx);
                found         = True;
            end
        end
    
        grantVecWire  <= grantVec;
        grantIdWire   <= grantId;
        grantIdReg    <= grantId;
    endrule

    rule demux;

    endrule
    
    // Now create the vector of interfaces
    Vector#(count, ArbiterClient_IFC) client_vector = newVector;
    
    for (Integer x = 0; x < icount; x = x + 1)
    
        client_vector[x] = (interface ArbiterClient_IFC
    
                    method Action request();
                    request_vector[x].send();
                    endmethod
    
                    method Action lock();
                    dummyAction;
                    endmethod
    
                    method grant ();
                    return grant_vector[x];
                    endmethod
                endinterface);
    
    interface clients = client_vector;
    method    grant_id = grant_id_wire;
    endmodule