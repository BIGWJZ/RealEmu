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

typedef 1024 MAX_DEV_NUM;

typedef 10 DEV_ID_WIDTH;
typedef 16 POWER_DB_WIDTH;
typedef 32 MPDU_LEN_WIDTH;
typedef 16 FC_WIDTH;
typedef 16 DI_WIDTH;

typedef 5 MCS_WIDRH;

typedef 64 HOST_ADDR_WIDTH;

typedef enum {
    WIFI_11A = 0,
    WIFI_11B = 1,
    WIFI_11N = 2,
    WIFI_11AX = 3
}WifiProtocol deriving(Bits, Bounded, FShow);

typedef Bit#(DEV_ID_WIDTH)    MacId;
typedef Bit#(POWER_DB_WIDTH)  PowerDb;
typedef Bit#(FC_WIDTH)        FrameCtl;
typedef Bit#(DI_WIDTH)        Duration;
typedef Bit#(MPDU_LEN_WIDTH)  MpduLen;
typedef Bit#(HOST_ADDR_WIDTH) MpduCacheAddr;

typedef Bit#(MCS_WIDRH) Mcs;

typedef struct {
    PowerDb power;
    Mcs     mcs;
}RfParam deriving(Bits, Bounded, FShow);

typedef struct {
    // Mac Header
    FrameCtl frameControl;
    Duration duration;
    // For sw operation
    MpduLen  length;
    MpduCacheAddr cacheAddr;
} MpduDigest deriving(Bits, Bounded, FShow);

// Emulation Info Event, a digest of 802.11 MPDU from upper nodes
typedef struct {
    // Translated from Mac Addr to Id by driver
    MacId srcMacId;
    MacId dstMacId;
    // Extra Param
    Bool    hasRfParam;
    RfParam rfParam;
    MpduDigest mpduDigest;
}EmuInfoEvent deriving(Bits, Bounded, FShow);

typedef enum {
    COPY,
    DESTROY
}ScheOpCode deriving(Bits, Bounded, FShow);

// Emulation Schedule Event, a indicatior for software operation
typedef struct {
    MacId srcMacId;
    MacId dstMacId;
    MpduLen mpduLen;
    MpduCacheAddr mpduCacheAddr;
    ScheOpCode opCode;
}EmuScheEvent deriving(Bits, Bounded, FShow);


// Low-Mac Core meta input&output, from High-Mac
typedef EmuInfoEvent MacTxReq;
typedef struct {
} MacTxResp deriving(Bits, Bounded, FShow);;
typedef EmuScheEvent MacRxReq;
typedef struct {
} MacRxResp deriving(Bits, Bounded, FShow);;

typedef Server#(MacTxReq, MacTxResp) MacTxSrv;
typedef Client#(MacTxReq, MacTxResp) MacTxClt;

typedef Server#(MacRxReq, MacRxResp) MacRxSrv;
typedef Client#(MacRxReq, MacRxResp) MacRxClt;


// Phy sturctures
typedef 16 RSSI_WIDTH;
typedef Bit#(RSSI_WIDTH) RSSI;

typedef 32 PPDU_LEN_WIDTH;
typedef Bit#(32) PpduLen;

typedef MacId PhyId;

typedef enum {
    S_Idle,
    S_SyncWindow,
    S_Decoding,
    S_Busy,
    S_AssertTrans,
}PhyRxFsmState deriving(Bits, Bounded, FShow);

typedef struct {
    RSSI rssi;
    PowerDb rxPower;
    Bool cca;
    Bool isTxing;
    PhyRxFsmState state;
}PhyStatus deriving(Bits, Bounded, FShow);

typedef struct {
}PhyTxResp deriving(Bits, Bounded, FShow);

typedef struct {
    PhyId srcId;
    PhyId dstId;
    RfParam rfParam;
    PpduLen ppduLen;
    MpduDigest mpduDigest;
}PhyTxReq deriving(Bits, Bounded, FShow);

typedef struct {
}PhyRxResp deriving(Bits, Bounded, FShow);

typedef PhyTxReq PhyRxReq;

interface Server#(PhyTxReq, PhyTxResp) PhyTxSrv;
interface Client#(PhyTxReq, PhyTxResp) PhyTxClt;

interface Server#(PhyRxReq, PhyRxResp) PhyRxSrv;
interface Client#(PhyRxReq, PhyRxResp) PhyRxClt;



