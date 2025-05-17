import GetPut::*;
import Connectable::*;
import ClientServer::*;
import Vector::*;
import FIFO::*;
import MathUtils::*;


import Types::*;
import Polling::*;
import Channel::*;

(* synthesize *)
module mkTopPoll(Empty);
    //实例化仲裁器
    PollIFC poll <- mkPoll;
    
    //创建节点模型
    Vector#(NODE_NUM, GainLossModel) nodes <- replicateM(mkGainLossModelIdeal);
    
    //连接接口
    for(Integer i = 0; i < valueOf(NODE_NUM); i = i + 1) begin
        mkConnection(nodes[i].phyTxMetaClt, poll.phyRxMetaSrv[i]);
        mkConnection(poll.phyTxMetaClt[i], nodes[i].phyRxMetaSrv);
    end

endmodule
