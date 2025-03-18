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
typedef 16 POWER_DB_WIDTH;  // (-128~127 dbm) * 256 = -32768~32767
typedef 8  POWER_DB_SHIFT_WIDTH; // 2^8 = 256
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
typedef Int#(POWER_DB_WIDTH)  PowerDb;  // (-128~127 dbm) * 256 = -32768~32767
typedef Bit#(FC_WIDTH)        FrameCtl;
typedef Bit#(DI_WIDTH)        Duration;
typedef Bit#(MPDU_LEN_WIDTH)  MpduLen;
typedef Bit#(HOST_ADDR_WIDTH) MpduCacheAddr;

typedef Bit#(MCS_WIDRH) Mcs;

typedef struct {
    PowerDb power;
    Mcs     mcs;
}RfParam deriving(Eq, Bits, Bounded, FShow);

function RfParam getEmptyRfParam();
    return RfParam{power: 0, mcs: 0};
endfunction

typedef struct {
    // Mac Header
    FrameCtl frameControl;
    Duration duration;
    // For sw operation
    MpduLen  length;
    MpduCacheAddr cacheAddr;
} MpduDigest deriving(Eq, Bits, Bounded, FShow);

function MpduDigest getEmptyMpduDigest();
    return MpduDigest{frameControl: 0, duration: 0, length: 0, cacheAddr: 0};
endfunction

// Emulation Info Event, a digest of 802.11 MPDU from upper nodes
typedef struct {
    // Translated from Mac Addr to Id by driver
    MacId srcMacId;
    MacId dstMacId;
    // Extra Param
    Bool    hasRfParam;
    RfParam rfParam;
    MpduDigest mpduDigest;
}EmuInfoEvent deriving(Eq, Bits, Bounded, FShow);

function EmuInfoEvent getEmptyEmuInfoEvent();
    return EmuInfoEvent{
        srcMacId  : 0, 
        dstMacId  : 0, 
        hasRfParam: False, 
        rfParam   : getEmptyRfParam, 
        mpduDigest: getEmptyMpduDigest
    };
endfunction

typedef enum {
    COPY,
    DESTROY
}ScheOpCode deriving(Eq, Bits, Bounded, FShow);

// Emulation Schedule Event, a indicatior for software operation
typedef struct {
    MacId srcMacId;
    MacId dstMacId;
    MpduLen mpduLen;
    MpduCacheAddr mpduCacheAddr;
    ScheOpCode opCode;
}EmuScheEvent deriving(Eq, Bits, Bounded, FShow);


// Low-Mac Core meta input&output, from High-Mac
typedef EmuInfoEvent MacTxReq;
typedef struct {
} MacTxResp deriving(Eq, Bits, Bounded, FShow);
typedef EmuScheEvent MacRxReq;
typedef struct {
} MacRxResp deriving(Eq, Bits, Bounded, FShow);

typedef Server#(MacTxReq, MacTxResp) MacTxSrv;
typedef Client#(MacTxReq, MacTxResp) MacTxClt;

typedef Server#(MacRxReq, MacRxResp) MacRxSrv;
typedef Client#(MacRxReq, MacRxResp) MacRxClt;

typedef 16 CW_WIDTH;
typedef Bit#(CW_WIDTH) ContWindow;
typedef Bit#(4) RetryTime;

typedef struct {
    ContWindow cwMin;
    ContWindow cwMax;
    RetryTime  retryLimit;
    Bool       navEn;
    Bool       txopEn;
    Bool       filterEn;
}MacConfig deriving(Eq, Bits, Bounded, FShow);

typedef struct {

}MacStatus deriving(Eq, Bits, Bounded, FShow);

typedef MacConfig MacCfgReq;
typedef MacStatus MacCfgResp;


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
    S_AssertTrans
}PhyRxFsmState deriving(Eq, Bits, Bounded, FShow);

typedef struct {
    RSSI rssi;
    PowerDb rxPower;
    Bool cca;
    Bool isTxing;
    PhyRxFsmState state;
}PhyFSM deriving(Eq, Bits, Bounded, FShow);

typedef struct {
}PhyTxResp deriving(Eq, Bits, Bounded, FShow);

typedef struct {
    PhyId srcId;
    PhyId dstId;
    RfParam rfParam;
    PpduLen ppduLen;
    MpduDigest mpduDigest;
}PhyTxReq deriving(Eq, Bits, Bounded, FShow);

function PhyTxReq getEmptyPhyReq();
    return PhyTxReq{
        srcId  : 0, 
        dstId  : 0, 
        rfParam: getEmptyRfParam, 
        ppduLen: 0, 
        mpduDigest: getEmptyMpduDigest};
endfunction

typedef struct {
}PhyRxResp deriving(Eq, Bits, Bounded, FShow);

typedef PhyTxReq PhyRxReq;

typedef Server#(PhyTxReq, PhyTxResp) PhyTxSrv;
typedef Client#(PhyTxReq, PhyTxResp) PhyTxClt;

typedef Server#(PhyRxReq, PhyRxResp) PhyRxSrv;
typedef Client#(PhyRxReq, PhyRxResp) PhyRxClt;


// Channel Types

typedef 16 DISTANCE_WIDTH;
typedef Bit#(DISTANCE_WIDTH) NodeDistance;

typedef Bit#(3) LogDistParaN;
typedef Bit#(8) LogDistPataL0;

typedef struct {
    LogDistParaN  n;
    LogDistPataL0 l0;
}LogDistanceParam deriving(Eq, Bits, Bounded, FShow);
