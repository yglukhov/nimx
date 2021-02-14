import json, logging
import url_stream

when defined(js):
    import jsbind, web_url_handler

proc loadJsonFromURL*(url: string, handler: proc(j: JsonNode)) =
    when defined(js):
        let reqListener = proc(str: JSObj) =
            handler(parseJson($(cast[cstring](str))))
        loadJSURL(url, "text", nil, nil, reqListener)
    else:
        openStreamForUrl(url) do(s: Stream, err: string):
            if err.len == 0:
                handler(parseJson(s, url))
                s.close()
            else:
                error "Error loading json from url (", url, "): ", err
                handler(nil)
