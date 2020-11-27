import asyncdispatch

when defined(windows):
  import winlean, logging, deques, os
  const overlappedKey = 98765 # Just an arbitrary number

  var customOverlapped: CustomRef
  var pendingMessages: Deque[pointer]
  var pendingFuture: Future[pointer]
  var completionPort: Handle

  proc onEvent(fd: AsyncFD, data: DWORD, errcode: OSErrorCode) =
    {.gcsafe.}:
      GC_ref(customOverlapped) # It is GC_unreffed every time in asyncdispatch.nim
      let data = cast[pointer](data)
      if pendingFuture != nil:
        let f = pendingFuture
        pendingFuture = nil
        f.complete(data)
      else:
        if pendingMessages.len < 2048:
          pendingMessages.addLast(data)
        else:
          error "Message queue overflow"

  proc dummyTimerLoop() {.async.} =
    while true:
      await sleepAsync(10.minutes)

else:
  import posix, asyncfile
  proc setNonBlocking(fd: cint) {.inline.} =
    var x = fcntl(fd, F_GETFL, 0)
    if x != -1:
      var mode = x or O_NONBLOCK
      discard fcntl(fd, F_SETFL, mode)

  var pipeWriteEnd: cint
  var pipeReadEnd: AsyncFile
  var pipeReadEndFd: AsyncFd

proc init*() {.inline.} =
  when defined(windows):
    customOverlapped = newCustom()
    customOverlapped.data = CompletionData(fd: cast[AsyncFd](overlappedKey), cb: onEvent)
    pendingMessages = initDeque[pointer]()
    completionPort = getGlobalDispatcher().getIoHandler()

    # We're sending events without dispatcher knowing about it,
    # so add a dummy timer to prevent it on failing because it's empty
    asyncCheck dummyTimerLoop()
  else:
    var pipeFds: array[2, cint]
    discard posix.pipe(pipeFds)
    setNonBlocking(pipeFds[0])
    pipeWriteEnd = pipeFds[1]
    pipeReadEndFd = AsyncFd(pipeFds[0])
    pipeReadEnd = newAsyncFile(pipeReadEndFd)

{.push stackTrace: off.}
proc sendAsyncMsg*(p: pointer) {.inline.} =
  when defined(windows):
    {.gcsafe.}:
      discard postQueuedCompletionStatus(completionPort, cast[DWORD](p), cast[ULONG_PTR](overlappedKey), cast[POVERLAPPED](customOverlapped))
  else:
    discard posix.write(pipeWriteEnd, unsafeAddr p, sizeof(p))
{.pop.}

when defined(windows):
  proc recvAsyncMsg*(): Future[pointer] =
    assert(pendingFuture.isNil)
    result = newFuture[pointer]("recvAsyncMsg")
    if pendingMessages.len != 0:
      let p = pendingMessages.popFirst()
      result.complete(p)
    else:
      pendingFuture = result

  proc recvAsyncMsgSync*(): pointer =
    assert(pendingFuture.isNil)
    if pendingMessages.len != 0:
      result = pendingMessages.popFirst()

else:
  proc recvAsyncMsg*(): Future[pointer] {.async.} =
    var p: pointer
    discard await pipeReadEnd.readBuffer(addr p, sizeof(p))
    return p

  proc recvAsyncMsgSync*(): pointer =
    var p: pointer
    if posix.read(pipeReadEndFd.cint, addr p, sizeof(p)) == sizeof(p):
      result = p
