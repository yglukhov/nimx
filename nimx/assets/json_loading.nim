import json, logging
import url_stream

when defined(wasm):
  import web_url_handler

proc loadJsonFromURL*(url: string, handler: proc(j: JsonNode) {.gcsafe.}) =
  openStreamForUrl(url) do(s: Stream, err: string):
    if err.len == 0:
      handler(parseJson(s, url))
      s.close()
    else:
      error "Error loading json from url (", url, "): ", err
      handler(nil)
