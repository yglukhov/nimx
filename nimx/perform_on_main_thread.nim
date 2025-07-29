
when (defined(macosx) or defined(ios)) and defined(nimxAvoidSDL):
  import private/objc_appkit

  enableObjC()

  {.emit: """
  #import <Foundation/Foundation.h>

  @interface __NimxMainThreadExecutor__ : NSObject {
    @public
    void (*func)(void*);
    void* data;
  }
  @end

  @implementation __NimxMainThreadExecutor__
  - (void) execute {
    func(data);
    [self release];
  }
  @end
  """.}

  {.push stack_trace:off.}
  proc performOnMainThread*(fun: proc(data: pointer) {.cdecl.}, data: pointer): int {.discardable.} =
    {.emit: """
    __NimxMainThreadExecutor__* executor = [[__NimxMainThreadExecutor__ alloc] init];
    executor->func = `fun`;
    executor->data = `data`;
    [executor performSelectorOnMainThread: @selector(execute) withObject: nil waitUntilDone: NO];
    """.}
  {.pop.}
elif (defined(linux) or defined(windows)) and not defined(android) and defined(nimxAvoidSDL):
  import locks, asyncdispatch

  type
    Elem = object
      p: proc(data: pointer) {.cdecl.}
      d: pointer

    SharedArray[T] = object
      data: ptr UncheckedArray[T]
      len, cap: int
      lock: Lock

  proc init[T](s: var SharedArray[T]) =
    initLock(s.lock)

  {.push stackTrace: off.}
  proc add[T](s: var SharedArray[T], v: T) =
    acquire(s.lock)
    if s.cap == s.len:
      s.cap += 4
      s.data = cast[ptr UncheckedArray[T]](reallocShared(s.data, s.cap * sizeof(T)))
    s.data[s.len] = v
    inc s.len
    release(s.lock)
  {.pop.}

  var callbacks: SharedArray[(proc(data: pointer) {.cdecl.}, pointer)]
  callbacks.init()
  var event = newAsyncEvent()
  addEvent(event) do(f: AsyncFD) -> bool {.gcsafe.}:
    acquire(callbacks.lock)
    for i in 0 ..< callbacks.len:
      let e = callbacks.data[i]
      try:
        {.gcsafe.}:
          e[0](e[1])
      except Exception as e:
        echo "Exception while performing callback on main thread: ", e.msg, ": ", e.getStackTrace()
    callbacks.len = 0
    release(callbacks.lock)

  {.push stack_trace:off.}
  proc performOnMainThread*(fun: proc(data: pointer) {.cdecl.}, data: pointer): int {.discardable.} =
    callbacks.add((fun, data))
    event.trigger()
  {.pop.}

else:
  import sdl2

  {.push stack_trace:off.}
  proc performOnMainThread*(fun: proc(data: pointer) {.cdecl.}, data: pointer): int {.discardable.} =
    var evt = UserEventObj(kind: UserEvent5)
    evt.data1 = fun
    evt.data2 = data
    result = pushEvent(cast[ptr Event](addr evt))
  {.pop.}
