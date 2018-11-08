import tables, ospaths, streams, variant, logging
import asset_cache, url_stream

type UrlLoaderProc* = proc(url, path: string, cache: AssetCache, handler: proc())
type SimpleUrlLoaderProc*[T] = proc(url: string, handler: proc(v: T))
type StreamLoaderProc* = proc(s: Stream, path: string, cache: AssetCache, handler: proc())
type SimpleStreamLoaderProc*[T] = proc(s: Stream, handler: proc(v: T))


const anyUrlScheme = "_"

var assetLoaders = newSeq[tuple[urlSchemes: seq[string], extensions: seq[string], loader: UrlLoaderProc]]()

var hackyResUrlLoader*: proc(url, path: string, cache: AssetCache, handler: proc(err: string))

proc registerAssetLoader*(urlSchemes: openarray[string], fileExtensions: openarray[string], loader: UrlLoaderProc) =
    assetLoaders.add((@urlSchemes, @fileExtensions, loader))

proc registerAssetLoader*[T](urlSchemes: openarray[string], fileExtensions: openarray[string], simpleLoader: SimpleUrlLoaderProc[T]) =
    let loader = proc(url, path: string, cache: AssetCache, handler: proc()) =
        simpleLoader(url) do(v: T):
            cache.registerAsset(path, v)
            handler()
    registerAssetLoader(urlSchemes, fileExtensions, loader)

# Any url scheme variants
proc registerAssetLoader*(fileExtensions: openarray[string], loader: UrlLoaderProc) {.inline.} =
    registerAssetLoader([anyUrlScheme], fileExtensions, loader)

proc registerAssetLoader*[T](fileExtensions: openarray[string], loader: SimpleUrlLoaderProc[T]) {.inline.} =
    registerAssetLoader([anyUrlScheme], fileExtensions, loader)

# Stream variants
proc registerAssetLoader*(fileExtensions: openarray[string], streamLoader: StreamLoaderProc) =
    let loader = proc(url, path: string, cache: AssetCache, handler: proc()) =
        openStreamForUrl(url) do(s: Stream, err: string):
            if err.len == 0:
                streamLoader(s, path, cache, handler)
            else:
                handler()
    registerAssetLoader([anyUrlScheme], fileExtensions, loader)

proc registerAssetLoader*[T](fileExtensions: openarray[string], streamLoader: SimpleStreamLoaderProc[T]) =
    let loader = proc(url, path: string, cache: AssetCache, handler: proc()) =
        openStreamForUrl(url) do(s: Stream, err: string):
            if err.len == 0:
                streamLoader(s) do(v: T):
                    s.close()
                    cache.registerAsset(path, v)
                    handler()
            else:
                handler()
    registerAssetLoader([anyUrlScheme], fileExtensions, loader)

proc urlScheme(s: string): string =
    let i = s.find(':') - 1
    if i > 0:
        result = s.substr(0, i)

proc getExt(path: string): string =
    path.splitFile().ext.substr(1)

proc loadAsset*(url, path: string, cache: AssetCache, handler: proc()) =
    let scheme = url.urlScheme()
    if scheme == "res":
        hackyResUrlLoader(url, path, cache) do(err: string):
            if err.len != 0:
                error "loading asset ", url, ": ", err
            handler()
        return

    var genericLoader = -1
    for i in 0 ..< assetLoaders.len:
        if getExt(url) in assetLoaders[i].extensions:
            if scheme in assetLoaders[i].urlSchemes: # Perfect match:
                assetLoaders[i].loader(url, path, cache, handler)
                return
            elif anyUrlScheme in assetLoaders[i].urlSchemes: # Generic match
                genericLoader = i

    if genericLoader != -1:
        assetLoaders[genericLoader].loader(url, path, cache, handler)
        return

    raise newException(Exception, "No asset loader found for url: " & url)

proc loadAsset*[T](url: string, handler: proc(a: T, err: string)) =
    let c = newAssetCache()
    loadAsset(url, "k", c) do():
        let v = c.getOrDefault("k")
        if v.ofType(T):
            handler(v.get(T), "")
        else:
            var b: T
            handler(b, "Wrong  asset type")
