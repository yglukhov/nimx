import json
import url_stream, web_url_handler

when defined(js):
    import jsbind

proc loadJsonFromURL*(url: string, handler: proc(j: JsonNode)) =
    when defined(js):
        let reqListener = proc(str: JSObj) =
            handler(parseJson($(cast[cstring](str))))
        loadJSURL(url, "text", nil, nil, reqListener)
    else:
        openStreamForUrl(url) do(s: Stream, err: string):
            handler(parseJson(s, url))
            s.close()
