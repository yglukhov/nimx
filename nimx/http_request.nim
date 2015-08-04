when not defined(js):
    import asyncdispatch, httpclient, sdl2, sdl_perform_on_main_thread
    when defined(android):
        # For some reason pthread_t is not defined on android
        {.emit: """/*INCLUDESECTION*/
        #include <pthread.h>"""
        .}


    type RequestHandler = ref object
        handlerProc: proc(data: string)
        handlerData: pointer

    type ThreadArg = object
        url: string
        httpMethod: string
        extraHeaders: string
        body: string
        handler: pointer

    proc cHandler(a: pointer) {.cdecl.} =
        let rh = cast[RequestHandler](a)
        GC_unref(rh)
        rh.handlerProc($(cast[cstring](rh.handlerData)))
        deallocShared(rh.handlerData)

    proc ayncHTTPRequest(a: ThreadArg) {.thread.} =
        let resp = request(a.url, "http" & a.httpMethod, a.extraHeaders, a.body, sslContext = nil)
        let rh = cast[RequestHandler](a.handler)
        rh.handlerData = allocShared(resp.body.len + 1)
        copyMem(rh.handlerData, cstring(resp.body), resp.body.len + 1)
        performOnMainThread(cHandler, a.handler)

proc sendRequest*(meth, url, body: string, headers: openarray[(string, string)], handler: proc(data: string)) =
    when defined(js):
        let cmeth : cstring = meth
        let curl : cstring = url
        let cbody : cstring = body

        let reqListener = proc (r: cstring) =
            handler($r)

        {.emit: """
        var oReq = new XMLHttpRequest();
        oReq.responseType = "text";
        oReq.addEventListener('load', `reqListener`);
        oReq.open(`cmeth`, `curl`, true);
        oReq.send(`cbody`);
        """.}
    else:
        var t : ref Thread[ThreadArg]
        t.new()

        var rh : RequestHandler
        rh.new()
        GC_ref(rh)
        rh.handlerProc = handler

        var extraHeaders = ""
        for h in headers:
            extraHeaders &= h[0] & ": " & h[1] & "\n\r"
        createThread(t[], ayncHTTPRequest, ThreadArg(url: url, httpMethod: meth, extraHeaders: extraHeaders, body: body, handler: cast[pointer](rh)))
