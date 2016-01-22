import streams

when not defined(js):
    {.error: "This module should be used only in JS.".}

type DataView = ref RootObj

type DataViewStream* = ref object of Stream
    view*: DataView
    pos: int

{.emit: """
    var gLittleEndian = (function() {
      var buffer = new ArrayBuffer(2);
      new DataView(buffer).setInt16(0, 256, true);
      return new Int16Array(buffer)[0] === 256;
    })();
""".}

proc abReadData(st: Stream, buffer: pointer, bufLen: int): int =
    let s = DataViewStream(st)
    let pos = s.pos
    let view = s.view
    {.emit: """
    var ok = false;
    if (`view`.byteLength === `pos` || `bufLen` === 0) {
        `result` = 0; // At end
        `ok` = true;
    }
    else if (`buffer`.length == 1) {
        if (`buffer`[0] === 0) {
            if (`bufLen` == 1) {
                // Int8 or char is expected
                `buffer`[`buffer`_Idx] = `view`.getInt8(`pos`);
                `pos` += 1;
                `result` = 1;
                ok = true;
            }
            else if (`bufLen` == 2) {
                // Int16 is expected
                `buffer`[`buffer`_Idx] = `view`.getInt16(`pos`, gLittleEndian);
                `pos` += 2;
                `result` = 2;
                ok = true;
            }
            else if (`bufLen` == 4) {
                // Int32 of Float32 expected
                `buffer`[`buffer`_Idx] = `view`.getInt32(`pos`, gLittleEndian);
                `pos` += 4;
                `result` = 4;
                ok = true;
            }
        }
        else if (`buffer`[0] === 0.0) {
            if (`bufLen` == 4) {
                console.log("Reading float32")
                `buffer`[`buffer`_Idx] = `view`.getFloat32(`pos`, gLittleEndian);
                `pos` += 4;
                `result` = 4;
                ok = true;
            }
            else if (`bufLen` == 8) {
                console.log("Reading float64")
                `buffer`[`buffer`_Idx] = `view`.getFloat64(`pos`, gLittleEndian);
                `pos` += 8;
                `result` = 8;
                ok = true;
            }
        }
    }
    else if (`buffer`.length - 1 == `bufLen` + `buffer`_Idx) {
        // String is expected
        var toRead = `bufLen`;
        if (`pos` + `bufLen` >= `view`.byteLength) `bufLen` = `view`.byteLength - `pos`;
        for (var i = 0; i < `bufLen`; ++i) {
            `buffer`[i + `buffer`_Idx] = `view`.getUint8(`pos` + i);
        }
        `pos` += `bufLen`;
        `result` = `bufLen`;
        ok = true;
    }

    if (!ok) {
        console.log("buf type: ", typeof(`buffer`))
        //console.log("buf: ", `buffer`);
        console.log("bufLen: ", `bufLen`);
        console.log("idx: ", `buffer`_Idx);
        console.log("len: ", `bufLen`);
        console.log("result: ", `result`);
        console.log("newPos: ", `pos`);
        console.log("---------");
    }
    """.}
    s.pos = pos

proc growDataViewSize(dataView: DataView, to: int): DataView =
    result = dataView
    {.emit: """
    var len = `dataView`.byteLength;
    if (len < to) {
        do {
            len *= 2;
        } while(len < to);
        var newBuf = new ArrayBuffer(len);
        var newView = new Int32Array(newBuf);
        var oldView = new Int32Array(`dataView`.buffer);
        var oldLen = oldView.length;
        for (var i = 0; i < oldLen; ++ i) newView[i] = oldView[i];
        `result` = new DataView(newBuf);
    }
    """.}

proc abWriteData(st: Stream; buffer: pointer; bufLen: int) =
    let s = DataViewStream(st)
    let pos = s.pos
    var view = s.view
    var newPos = pos
    {.emit: """
    var ok = false;
    if (`bufLen` === 0) {
        `result` = 0;
        `ok` = true;
    }
    else {
        // Realloc buffer
        var len = `view`.byteLength;
        var toLen = `pos` + `bufLen`;
        if (len < toLen) {
            do {
                len *= 2;
            } while(len < toLen);
            var newBuf = new ArrayBuffer(len);
            var newView = new Int32Array(newBuf);
            var oldView = new Int32Array(`view`.buffer);
            var oldLen = oldView.length;
            for (var i = 0; i < oldLen; ++ i) newView[i] = oldView[i];
            `view` = new DataView(newBuf);
        }

        if (`buffer`.length == 1) {
            if (`bufLen` == 1) {
                // Int8 or char is expected
                `view`.setInt8(`pos`, `buffer`[`buffer`_Idx])
                `pos` += 1;
                `result` = 1;
                ok = true;
            }
            else if (`bufLen` == 2) {
                // Int16 is expected
                `view`.setInt16(`pos`, `buffer`[`buffer`_Idx], gLittleEndian);
                `pos` += 2;
                `result` = 2;
                ok = true;
            }
            else if (`bufLen` == 4) {
                // Int32 of Float32 expected
                `view`.setInt32(`pos`, `buffer`[`buffer`_Idx], gLittleEndian);
                `pos` += 4;
                `result` = 4;
                ok = true;
            }
            else if (`buffer`[0] === 0.0) { // TODO: Not supported
                if (`bufLen` == 4) {
                    console.log("Reading float32")
                    `view`.setFloat32(`pos`, `buffer`[`buffer`_Idx], gLittleEndian);
                    `pos` += 4;
                    `result` = 4;
                    ok = true;
                }
                else if (`bufLen` == 8) {
                    console.log("Reading float64")
                    `view`.setFloat64(`pos`, `buffer`[`buffer`_Idx], gLittleEndian);
                    `pos` += 8;
                    `result` = 8;
                    ok = true;
                }
            }
        }
        else if (`buffer`.length - 1 == `bufLen` + `buffer`_Idx) {
            // String is expected
            for (var i = 0; i < `bufLen`; ++i) {
                `view`.setUint8(`pos` + i, `buffer`[i + `buffer`_Idx]);
            }
            `pos` += `bufLen`;
            `result` = `bufLen`;
            ok = true;
        }
    }

    if (!ok) {
        console.log("buf type: ", typeof(`buffer`))
        console.log("buf: ", `buffer`);
        console.log("bufLen: ", `bufLen`);
        console.log("idx: ", `buffer`_Idx);
        console.log("result: ", `result`);
        console.log("newPos: ", `pos`);
        console.log("---------");
    }
    """.}
    s.pos = pos
    s.view = view

proc abAtEnd(st: Stream): bool =
    let s = DataViewStream(st)
    let view = s.view
    let pos = s.pos
    {.emit: "`result` = `pos` == `view`.byteLength;".}

proc abGetPos(st: Stream): int =
    let s = DataViewStream(st)
    let pos = s.pos
    {.emit: "`result` = `pos`;".}

proc newStreamWithDataView*(v: DataView): Stream =
    let r = DataViewStream.new()
    r.view = v
    r.readDataImpl = abReadData
    r.atEndImpl = abAtEnd
    result = r

proc makeDataView(): DataView =
    {.emit: """`result` = new DataView(new ArrayBuffer(512));"""}

proc newDataViewWriteStream*(): Stream =
    let r = DataViewStream.new()
    r.view = makeDataView()
    r.readDataImpl = abReadData
    r.writeDataImpl = abWriteData
    result = r
