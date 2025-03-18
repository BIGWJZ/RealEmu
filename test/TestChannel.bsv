import ClientServer::*;
import GetPut::*;
import FIFO::*;
import Randomizable::*;
import BRAM::*;
import Vector::*;

import Channel::*;
import ROM::*;
import Types::*;
import PrimUtils::*;

typedef 100 TestNum;

module mkTestLogDistanceGainLossModel(Empty);
    // Configure all links' distance are 1, i.e. loss is 0
    BRAM2Port#(ChBramAddr, NodeDistance) distanceRam2 <- mkBRAM2Server(
        BRAM_Configure {                            
            memorySize   : 0,                       
            loadFormat   : tagged Hex "bram_one.txt",     
            latency      : 2,                          
            outFIFODepth : 4,                          
            allowWriteResponseBypass : False           
        }
    );

    // Only for simulation
    BRAM1Port#(UInt#(16), UInt#(16)) logRam1 <- mkBRAM1Server(
        BRAM_Configure {                            
            memorySize   : 0,                       
            loadFormat   : tagged Hex "bram_gainloss_512.txt",     
            latency      : 1,                          
            outFIFODepth : 2,                          
            allowWriteResponseBypass : False           
        }
    );

    let dut <- mkGainLossModelLogDistance(distanceRam2);

    FIFO#(PowerDb)     pipeQ    <- mkSizedFIFO(5);
    FIFO#(PowerDb)     txPowerQ <- mkSizedFIFO(5);

    Randomize#(PowerDb)      powerGen <- mkConstrainedRandomizer(0, 30 << valueOf(POWER_DB_SHIFT_WIDTH));    // tx power: 0~30dB
    Randomize#(NodeDistance) distGen  <- mkConstrainedRandomizer(0, 4096);  // node distance: 0~4km

    Reg#(Bool)      isInitReg    <- mkReg(False);
    Reg#(UInt#(32)) cntReg       <- mkReg(0);

    rule testInit if (!isInitReg);
        isInitReg <= True;
        powerGen.cntrl.init;
        distGen.cntrl.init;
    endrule

    rule genTxReq if (isInitReg);
        // Generate new tx request
        let txPower <- powerGen.next;
        let txReq = getEmptyPhyReq;
        txReq.rfParam.power = txPower;
        dut.phyTxMetaSrv.request.put(txReq);
        // Modify the nodes' distance in RAM
        let newDistance <- distGen.next;
        let bramWrReq = BRAMRequest{             
            write: True,          
            responseOnWrite: False,  
            address: genChBramAddr(txReq.srcId, txReq.dstId),            
            datain: newDistance             
        };
        distanceRam2.portA.request.put(bramWrReq);
        $display("Generated TxEvent with power: %d dB, distance : %d m", 
                    txPower >> valueOf(POWER_DB_SHIFT_WIDTH), newDistance);
        txPowerQ.enq(txPower);
        // Calculate ideal value
        let logRdReq = BRAMRequest{             
            write: False,          
            responseOnWrite: False,  
            address: unpack(newDistance),            
            datain: 0             
        };
        logRam1.portA.request.put(logRdReq);
    endrule

    rule calcIdeal if (isInitReg);
        let logValue <- logRam1.portA.response.get;
        let txPower = txPowerQ.first;
        txPowerQ.deq;
        let ideaValue = txPower - unpack(pack(logValue));
        pipeQ.enq(ideaValue);
    endrule

    rule procTxHandshake if (isInitReg);
        let resp <- dut.phyTxMetaSrv.response.get;
    endrule

    rule procRxResp if (isInitReg);
        // Extract RxReq from the GainLossModel module
        let rxReq <- dut.phyRxMetaClt.request.get;
        let rxPower = rxReq.rfParam.power;
        $display("Get RxEvent out from channel with power: %d dB", rxPower >> valueOf(POWER_DB_SHIFT_WIDTH));
        let ideaPower = pipeQ.first;
        pipeQ.deq;
        dut.phyRxMetaClt.response.put(PhyRxResp{});
        immAssert(
            (ideaPower == rxPower) ,
            "Fixed Distance Loss Test @ mkTestLogDistanceGainLossModel",
            $format("Error: rx Power: %d dBm, idea Power: %d dBm",
                        rxPower >> valueOf(POWER_DB_SHIFT_WIDTH), ideaPower >> valueOf(POWER_DB_SHIFT_WIDTH))
        );
        cntReg <= cntReg + 1;
    endrule

    rule testEnd if (isInitReg && cntReg == fromInteger(valueOf(TestNum)));
        $display("Test Pass!");
        $finish();
    endrule
        

endmodule


module mkTestFreeSpaceChannel(Empty);

endmodule