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
import DReg::*;
import FIFO::*;
import RegFile::*;

interface Rom1port#(type addr, type data);
    interface Put#(addr) request;
    interface Get#(data) response;
endinterface
    

interface RawRom1port#(numeric type addrSz, numeric type dataSz);
    method Action query(Bit#(addrSz) addr);
    method Bit#(dataSz) getResult();
endinterface

import "BVI" ROM1 =
module mkRawSingleRom#(String initFile)(RawRom1port#(addrSz, dataSz))
    provisos (Add#(0, addrSz, addrSz), Add#(0, dataSz, dataSz));

    default_clock clk(CLK);
    default_reset no_reset;

    parameter ADDR_WIDTH = valueOf(addrSz);
    parameter DATA_WIDTH = valueOf(dataSz);
    parameter HEX_FILE   = initFile;
    
    method query (ADDR) enable((*inhigh*) EN);

    method DOUT getResult();

    schedule query C query;
    schedule query CF getResult;
    schedule getResult C getResult;

endmodule

module mkSingleRom#(String initFile
)(
    Rom1port#(addrT, dataT)
) provisos(Bits#(addrT, addrSz), Bits#(dataT, dataSz), Add#(0, addrSz, addrSz), Add#(0, dataSz, dataSz), Literal#(addrT));
`ifdef BSIM
    RawRom1port#(addrSz, dataSz) rawRom <- mkRawSingleRom(initFile);

    Reg#(Bool)   rdFlagReg <- mkDReg(False);
    RWire#(addrT) addrWire  <- mkRWire;

    FIFO#(dataT) outQ  <- mkFIFO;

    rule getResult if (rdFlagReg);
        outQ.enq(unpack(rawRom.getResult));
    endrule

    rule putQuery;
        let addrMb = addrWire.wget;
        if (isValid(addrMb))
            rawRom.query(pack(fromMaybe(?, addrMb)));
        else
            rawRom.query(0);
    endrule

    interface Put request;
        method Action put(addr);
            rdFlagReg <= True;
            addrWire.wset(addr);
        endmethod
    endinterface    

    interface response = toGet(outQ);

`else
    RegFile#(addrT, dataT) regs <- mkRegFileLoad(initFile, fromInteger(0), fromInteger(valueOf(TSub#(TExp#(addrSz), 1))));
    FIFO#(dataT) outQ  <- mkFIFO;

    interface Put request;
        method Action put(addr);
            outQ.enq(regs.sub(addr));
        endmethod
    endinterface

    interface Get response = toGet(outQ);

`endif 
endmodule

