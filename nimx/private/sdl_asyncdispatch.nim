import asyncdispatch
import sdl2

const pollSdlInThread = defined(windows) or defined(linux)

when pollSdlInThread:
  import async_int_channel
  var thr: Thread[int]

  proc threadFunc(a: int) {.thread.} =
    while true:
      let e = cast[ptr Event](allocShared(sizeof(Event)))
      while not waitEvent(e[]): discard
      sendAsyncMsg(e)

proc initAsyncSdlLoop*() {.inline.} =
  when pollSdlInThread:
    async_int_channel.init()
    createThread(thr, threadFunc, 0)

proc sdlAsyncPollEvent*(e: var Event): bool =
  when pollSdlInThread:
    let p = recvAsyncMsgSync()
    if not p.isNil:
      result = true
      copyMem(addr e, p, sizeof(e))
      deallocShared(p)
  else:
    sdl.pollEvent(e)

proc sdlAsyncWaitEvent*(e: var Event): bool =
  when pollSdlInThread:
    let p = waitFor recvAsyncMsg()
    if not p.isNil:
      result = true
      copyMem(addr e, p, sizeof(e))
      deallocShared(p)
  else:
    sdl.pollEvent(e)
