import locks

type TaskListNode = object
    p: proc(data: pointer) {.cdecl, gcsafe.}
    data: pointer
    next: ptr TaskListNode

type
    WorkerQueue* = ref WorkerQueueObj
    WorkerQueueObj = object
        queueCond: Cond
        queueLock: Lock
        taskList: ptr TaskListNode
        lastTask: ptr TaskListNode
        threads: seq[Thread[pointer]]

# proc finalize(w: WorkerQueue) =
#     # This will not work, so it's not used.
#     # This is a leak! It's used in nimx image because it's global anyway.
#     w.queueCond.deinitCond()
#     w.queueLock.deinitLock()

proc threadWorker(qu: pointer) {.thread.} =
    let q = cast[ptr WorkerQueueObj](qu)
    while true:
        var t: ptr TaskListNode
        q.queueLock.acquire()

        while q.taskList.isNil:
            q.queueCond.wait(q.queueLock)

        t = q.taskList
        if q.lastTask == q.taskList:
            q.taskList = nil
            q.lastTask = nil
        else:
            q.taskList = t.next

        q.queueLock.release()
        t.p(t.data)
        deallocShared(t)

proc newWorkerQueue*(maxThreads : int = 0): WorkerQueue =
    result.new()
    result.queueCond.initCond()
    result.queueLock.initLock()
    let mt = if maxThreads == 0: 2 else: maxThreads
    result.threads.newSeq(mt)
    for i in 0 ..< mt:
        result.threads[i].createThread(threadWorker, cast[pointer](result))

proc addTask*(q: WorkerQueue, p: proc(data: pointer) {.cdecl, gcsafe.}, data: pointer) =
    let task = cast[ptr TaskListNode](allocShared(sizeof(TaskListNode)))
    task.p = p
    task.data = data
    q.queueLock.acquire()
    if q.taskList.isNil:
        q.taskList = task
        q.lastTask = task
    else:
        q.lastTask.next = task
        q.lastTask = task
    q.queueCond.signal()
    q.queueLock.release()

when isMainModule:
    import os
    proc worker(data: pointer) {.cdecl.} =
        echo "worker doing: ", cast[int](data)
        sleep(500)

    let q = newWorkerQueue(4)
    q.addTask(worker, cast[pointer](1))
    q.addTask(worker, cast[pointer](2))
    q.addTask(worker, cast[pointer](3))
    q.addTask(worker, cast[pointer](4))
    sleep(5000)
