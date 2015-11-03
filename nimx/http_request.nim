import async_http_request
export async_http_request

when not defined(js):
    import sdl2, sdl_perform_on_main_thread, marshal, streams

    proc storeToSharedBuffer*[T](a: T): pointer =
        let s = newStringStream()
        store(s, a)
        result = allocShared(s.data.len + sizeof(uint64))
        cast[ptr uint64](result)[] = s.data.len.uint64
        copyMem(cast[pointer](cast[int](result) + sizeof(uint64)), addr s.data[0], s.data.len)
        s.close()

    proc readFromSharedBuffer*[T](p: pointer, res: var T) =
        let bufLen = cast[ptr uint64](p)[]
        var str = newStringOfCap(bufLen)
        str.setLen(bufLen)
        copyMem(addr str[0], cast[pointer](cast[int](p) + sizeof(uint64)), bufLen)
        let s = newStringStream(str)
        load(s, res)
        s.close()

    proc sendRequest*(meth, url, body: string, headers: openarray[(string, string)], handler: Handler) =
        type SdlHandlerContext = object
            handler: Handler
            data: pointer

        let ctx = cast[ptr SdlHandlerContext](allocShared(sizeof(SdlHandlerContext)))
        ctx.handler = handler

        proc callHandler(c: pointer) {.cdecl.} =
            let ctx = cast[ptr SdlHandlerContext](c)
            var r: Response
            readFromSharedBuffer(ctx.data, r)
            deallocShared(ctx.data)
            ctx.handler(r)
            deallocShared(ctx)

        proc sdlThreadSafeHandler(r: Response, ctx: pointer) {.nimcall.} =
            cast[ptr SdlHandlerContext](ctx).data = storeToSharedBuffer(r)
            performOnMainThread(callHandler, ctx)

        sendRequestThreaded(meth, url, body, headers, sdlThreadSafeHandler, ctx)
