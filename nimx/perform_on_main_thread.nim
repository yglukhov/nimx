
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

else:
    import sdl2

    {.push stack_trace:off.}
    proc performOnMainThread*(fun: proc(data: pointer) {.cdecl.}, data: pointer): int {.discardable.} =
        var evt = UserEventObj(kind: UserEvent5)
        evt.data1 = fun
        evt.data2 = data
        result = pushEvent(cast[ptr Event](addr evt))
    {.pop.}
