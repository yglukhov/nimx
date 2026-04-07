import url_stream
import async_http_request except Handler

import nimx/http_request except Handler

type URLLoadingError* = object
  description*: string

when defined(wasm):
  import logging
  import wasmrt

  proc errorDesc(r: XMLHTTPRequest, url: string): URLLoadingError =
    var statusText = r.statusText
    result.description = "XMLHTTPRequest error(" & url & "): " & $r.status & ": " & $statusText
    warn "XMLHTTPRequest failure: ", result.description

  proc loadJSURL(url: string, onError: proc(e: URLLoadingError), onComplete: proc(result: JSObject)) =
    assert(not onComplete.isNil)

    let oReq = newXMLHTTPRequest().store()
    var reqListener: proc()
    var errorListener: proc()
    reqListener = proc() =
      # jsUnref(reqListener)
      # jsUnref(errorListener)

      let r = oReq.get()
      let s = r.status
      if s > 300:
        let err = r.errorDesc(url)
        if not onError.isNil:
          onError(err)
      else:
        onComplete(r.response)
    errorListener = proc() =
      # jsUnref(reqListener)
      # jsUnref(errorListener)
      let err = oReq.get().errorDesc(url)
      if not onError.isNil:
        onError(err)
    # jsRef(reqListener)
    # jsRef(errorListener)

    # oReq.addEventListener("load", reqListener)
    # oReq.addEventListener("error", errorListener)
    oReq.open("GET", url)
    oReq.responseType = "arraybuffer"
    oReq.send()

  proc byteLength(b: JSObject): uint32 {.importwasmp.}
  proc uint8MemSlice(s: pointer, length: uint32): JSObject {.importwasmexpr: "new Uint8Array(_nima, $0, $1)".}
  proc uint8Mem(b: JSObject): JSObject {.importwasmf: "new Uint8Array".}
  proc setMem(a, b: JSObject) {.importwasmm: "set".}

  proc arrayBufferToString(arrayBuffer: JSObject): string {.inline.} =
    let sz = arrayBuffer.byteLength
    if sz != 0:
      result.setLen(sz.int)
      uint8MemSlice(addr result[0], sz).setMem(uint8Mem(arrayBuffer))

proc getHttpStream(url: string, handler: Handler) =
  {.gcsafe.}:
    when defined(wasm):
      let reqListener = proc(data: JSObject) =
        handler(newStringStream(arrayBufferToString(data)), "")

      let errorListener = proc(e: URLLoadingError) =
        handler(nil, e.description)

      loadJSURL(url, errorListener, reqListener)
    else:
      sendRequest("GET", url, "", []) do(r: Response):
        if r.statusCode >= 200 and r.statusCode < 300:
          var b: string
          shallowCopy(b, r.body)
          shallow(b)
          let s = newStringStream(r.body)
          handler(s, "")
        else:
          handler(nil, "Error downloading url " & url & ": " & $r.statusCode)

registerUrlHandler("http", getHttpStream)
registerUrlHandler("https", getHttpStream)

# when web:
#   when not defined(wasm):
#     registerUrlHandler("file", getHttpStream)
