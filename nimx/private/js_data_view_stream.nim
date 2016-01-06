import streams

when not defined(js):
    {.error: "This module should be used only in JS.".}

type DataViewStream = ref object of Stream
    view: ref RootObj # DataView
    pos: int

proc abReadData(st: Stream, buffer: pointer, bufLen: int): int =
    let s = DataViewStream(st)
    let oldPos = s.pos
    let view = s.view
    var newPos = oldPos
    {.emit: """
    if (`view`.byteLength == `oldPos`) {
        return 0;
    }
    if (`buffer`.length == 1) {
        if (`buffer`[0] === 0) {
            if (`bufLen` == 1) {
                // Int8 or char is expected
                `buffer`[`buffer`_Idx] = `view`.getInt8(`oldPos`);
                `newPos` += 1;
                `result` = 1;
                ok = true;
            }
            else if (`bufLen` == 2) {
                // Int16 is expected
                `buffer`[`buffer`_Idx] = `view`.getInt16(`oldPos`);
                `newPos` += 2;
                `result` = 2;
                ok = true;
            }
            else if (`bufLen` == 4) {
                // Int32 of Float32 expected
                `buffer`[`buffer`_Idx] = `view`.getInt32(`oldPos`);
                `newPos` += 4;
                `result` = 4;
                ok = true;
            }
        }
        else if (`buffer`[0] === 0.0) {
            if (`bufLen` == 4) {
                console.log("Reading float32")
                `buffer`[`buffer`_Idx] = `view`.getFloat32(`oldPos`);
                `newPos` += 4;
                `result` = 4;
                ok = true;
            }
            else if (`bufLen` == 8) {
                console.log("Reading float64")
                `buffer`[`buffer`_Idx] = `view`.getFloat64(`oldPos`);
                `newPos` += 8;
                `result` = 8;
                ok = true;
            }
        }
    }
    else if (`buffer`.length - 1 == `bufLen`) {
        // String is expected
        var toRead = `bufLen`;
        if (`oldPos` + `bufLen` >= `view`.byteLength) `bufLen` = `view`.byteLength - `oldPos`;
        for (var i = 0; i < `bufLen`; ++i) {
            `buffer`[i] = `view`.getInt8(`oldPos` + i);
        }
        `newPos` += `bufLen`;
        `result` = `bufLen`;
        ok = true;
    }

    if (!ok) {
        console.log("buf type: ", typeof(`buffer`))
        console.log("buf: ", `buffer`);
        console.log("idx: ", `buffer`_Idx);
        console.log("len: ", `bufLen`);
    }
    """.}
    s.pos = newPos

proc newStreamWithDataView*(v: ref RootObj): Stream =
    let r = DataViewStream.new()
    r.view = v
    r.readDataImpl = abReadData
    #r.atEndImpl
    result = r
