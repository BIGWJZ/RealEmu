
import GetPut::*;
import Connectable::*;
import ClientServer::*;

import Types::*;
import MacCore::*;
import CsmaUtils::*;
import PrimUtils::*;

// 组装一个节点的示例，仅供参考未运行
module mkTestOneNode(Empty);
    // 多节点测试请声明一个Node接口组装，并用for循环例化多个节点
    let mac0 = mkMacDCF(0);
    let phy0 = mkPhyYansWifi(0);

    let mac1 = mkMacDCF(1);
    let phy1 = mkPhyYansWifi(1);

    mkConnection(mac0.lowMacTxClt, phy0.lowMacTxSrv);
    mkConnection(mac0.lowMacRxSrv, phy0.lowMacRxClt);

    mkConnection(mac1.lowMacTxClt, phy1.lowMacTxSrv);
    mkConnection(mac1.lowMacRxSrv, phy1.lowMacRxClt);

    // 多节点测试时需要使用包含仲裁器和多路选择器的Channel模块，此处仅使用LogLoss模块

    BRAM2Port#(ChBramAddr, NodeDistance) distanceRam2 <- mkBRAM2Server(
        BRAM_Configure {                            
            memorySize   : 0,                       
            loadFormat   : tagged Hex "bram_one.txt",     
            latency      : 2,                          
            outFIFODepth : 4,                          
            allowWriteResponseBypass : False           
        }
    );

    let channel01 <- mkGainLossModelLogDistance(distanceRam2);
    let channel10 <- mkGainLossModelLogDistance(distanceRam2);

    mkConnection(phy0.phyTxClt, channel01.phyTxMetaSrv);
    mkConnection(phy1.phyRxSrv, channel01.phyRxMetaClt);

    mkConnection(phy1.phyTxClt, channel10.phyTxMetaSrv);
    mkConnection(phy0.phyRxSrv, channel10.phyRxMetaClt);

    // 请添加测试rule

endmodule
