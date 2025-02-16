
function Bool isZero(Bit#(nSz) bits); // provisos(Add#(1, anysize, nSz));
    Bool ret = unpack(|bits);
    return !ret;
endfunction

function Action immAssert(Bool condition, String assertName, Fmt assertFmtMsg);
    action
        let pos = printPosition(getStringPosition(assertName));
        // let pos = printPosition(getEvalPosition(condition));
        if (!condition) begin
            $error(
                "ImmAssert failed in %m @time=%0t: %s-- %s: ",
                $time, pos, assertName, assertFmtMsg
            );
            $finish(1);
        end
    endaction
endfunction