
import GetPut::*;
import Connectable::*;
import ClientServer::*;

import Types::*;
import PhyCore::*;
module mkTestBinarySearch(Empty);


    Reg#(UInt#(64)) cycleCount <- mkReg(0);

    rule updateclock;
        cycleCount <= cycleCount + 1;
    endrule

    BinarySearchIFC searcher <- mkBinarySearch;

    rule feed_test(cycleCount == 100);
        UInt#(32) target = 226256;
        searcher.put(target);
        $display("Binary searching %0d",target);
    endrule

    rule search_result;
        let res <- searcher.get;
        $display("Binary searched %0d",res);
    endrule

    rule simEnd(cycleCount == 100_000);//1ms
        $finish();
    endrule

endmodule