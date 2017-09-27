import url_stream
import async_http_request except Handler
import logging

import nimx.http_request except Handler

const web = defined(js) or defined(emscripten)

type URLLoadingError* = object
    description*: string

when web:
    import jsbind

    when defined(js):
        import nimx.private.js_data_view_stream

    proc errorDesc(r: XMLHTTPRequest, url: string): URLLoadingError =
        var statusText = r.statusText
        if statusText.isNil: statusText = "(nil)"
        result.description = "XMLHTTPRequest error(" & url & "): " & $r.status & ": " & $statusText
        warn "XMLHTTPRequest failure: ", result.description

    proc loadJSURL*(url: string, resourceType: cstring, onProgress: proc(p: float), onError: proc(e: URLLoadingError), onComplete: proc(result: JSObj)) =
        assert(not onComplete.isNil)

        let oReq = newXMLHTTPRequest()
        var reqListener: proc()
        var errorListener: proc()
        reqListener = proc() =
            jsUnref(reqListener)
            jsUnref(errorListener)
            let s = oReq.status
            if s > 300:
                let err = oReq.errorDesc(url)
                if not onError.isNil:
                    onError(err)
            else:
                onComplete(oReq.response)
        errorListener = proc() =
            jsUnref(reqListener)
            jsUnref(errorListener)
            let err = oReq.errorDesc(url)
            if not onError.isNil:
                onError(err)
        jsRef(reqListener)
        jsRef(errorListener)

        oReq.addEventListener("load", reqListener)
        oReq.addEventListener("error", errorListener)
        oReq.open("GET", url)
        oReq.responseType = resourceType
        oReq.send()

    when defined(emscripten):
        import jsbind.emscripten

        proc arrayBufferToString(arrayBuffer: JSObj): string {.inline.} =
            let r = EM_ASM_INT("""
            var a = new Int8Array(_nimem_o[$0]);
            var b = _nimem_ps(a.length);
            writeArrayToMemory(a, _nimem_sb(b));
            return b;
            """, arrayBuffer.p)
            result = cast[string](r)
            shallow(result)

proc getHttpStream(url: string, handler: Handler) =
    when web:
        let reqListener = proc(data: JSObj) =
            when defined(js):
                var dataView : ref RootObj
                {.emit: "`dataView` = new DataView(`data`);".}
                handler(newStreamWithDataView(dataView), nil)
            else:
                handler(newStringStream(arrayBufferToString(data)), nil)

        let errorListener = proc(e: URLLoadingError) =
            handler(nil, e.description)

        loadJSURL(url, "arraybuffer", nil, errorListener, reqListener)
    else:
        sendRequest("GET", url, nil, []) do(r: Response):
            if r.statusCode >= 200 and r.statusCode < 300:
                var b: string
                shallowCopy(b, r.body)
                shallow(b)
                let s = newStringStream(r.body)
                handler(s, nil)
            else:
                handler(nil, "Error downloading url " & url & ": " & $r.statusCode)

registerUrlHandler("http", getHttpStream)
registerUrlHandler("https", getHttpStream)

when web:
    registerUrlHandler("file", getHttpStream)

    when defined(emscripten):
        registerUrlHandler("emdata") do(url: string, handler: Handler):
            const prefixLen = len("file://")
            let p =  substr(url, prefixLen)
            let s = newFileStream(p, fmRead)
            if s.isNil:
                handler(nil, "Could not open file: " & url)
            else:
                handler(s, nil)
