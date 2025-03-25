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

import FIFOF::*;
import Vector::*;
import RegFile::*;
import GetPut::*;

import ROM::*;

interface Mul_IFC#(type numSz);
    interface Put#(Tuple2#(Bit#(numSz), Bit#(numSz))) request;
    interface Get#(Bit#(TAdd#(numSz, numSz))) response;
endinterface

typedef Rom1port#(UInt#(16), UInt#(16)) MathTable;

// TODO:
// module mkBoothMulU(Mul_IFC#(numSz));

// endmodule

// 10 * x = 8 * x + 2 * x = (x << 3) + (x << 1), unsigned
function Bit#(TAdd#(nSz, 4)) mul10u(Bit#(nSz) x);
    Bit#(TAdd#(nSz, 4)) ans = (zeroExtend(x) << 3) + (zeroExtend(x) << 1);
    return ans;
endfunction

/*
 * GainLoss = A * 10nlog(d/d0) = 512 * 20log(d)
 * GainLoss = 20 log (d), GainLoss is [0, 96.33]
 * Set the rom = 512 * GainLoss is [0, 49321]
*/

(* synthesize *)
module mkLogDistanceGainLossTable(MathTable);
    Rom1port#(UInt#(16), UInt#(16)) rom <- mkSingleRom("bram_gainloss_512.txt");
    interface request  = rom.request;
    interface response = rom.response;
endmodule
