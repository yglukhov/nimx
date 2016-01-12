import macros
import nimx.timer
import nimx.app
import nimx.event
import nimx.abstract_window
import nimx.system_logger

type UITestSuiteStep* = tuple
    code : proc()
    astrepr: string

type UITestSuite* = seq[UITestSuiteStep]

var registeredTests : seq[UITestSuite]

proc registerTest*(ts: UITestSuite) =
    if registeredTests.isNil:
        registeredTests = @[ts]
    else:
        registeredTests.add(ts)

proc testSuiteDefinitionWithNameAndBody(name, body: NimNode): NimNode =
    result = newNimNode(nnkBracket)
    for n in body:
        let procDef = newProc(body = newStmtList().add(n), procType = nnkLambda)
        procDef.pragma = newNimNode(nnkPragma).add(newIdentNode("closure"))

        let step = newNimNode(nnkPar).add(procDef, toStrLit(n))
        result.add(step)
    return newNimNode(nnkLetSection).add(
        newNimNode(nnkIdentDefs).add(name, bindsym "UITestSuite", newCall("@", result)))

macro uiTest*(name: untyped, body: typed): untyped =
    result = testSuiteDefinitionWithNameAndBody(name, body)

macro registeredUiTest*(name: untyped, body: typed): stmt =
    result = newStmtList()
    result.add(testSuiteDefinitionWithNameAndBody(name, body))
    result.add(newCall(bindsym "registerTest", name))

when true:
    proc sendMouseEvent*(wnd: Window, p: Point, bs: ButtonState) =
        var evt = newMouseButtonEvent(p, kcMouseButtonPrimary, bs)
        evt.window = wnd
        discard mainApplication().handleEvent(evt)

    proc sendMouseDownEvent*(wnd: Window, p: Point) = sendMouseEvent(wnd, p, bsDown)
    proc sendMouseUpEvent*(wnd: Window, p: Point) = sendMouseEvent(wnd, p, bsUp)

    proc quitApplication*() =
        when defined(js):
            # Hopefully we're using nimx automated testing in Firefox
            {.emit: """if ('dump' in window) window.dump("---AUTO-TEST-QUIT---\n");""".}
        else:
            quit()

when false:
    macro dump(b: typed): stmt =
        echo treeRepr(b)

    dump:
        let ts : UITestSuite = @[
            (
                (proc() {.closure.} = echo "hi"),
                "hello"
            )
        ]

    uiTest myTest:
        echo "hi"
        echo "bye"

    registerTest(myTest)

proc startTest*(t: UITestSuite) =
    var curTest = 0
    var tim : Timer
    tim = setInterval(0.5, proc() =
        logi "RUNNING"
        logi t[curTest].astrepr
        t[curTest].code()
        inc curTest
        if curTest == t.len:
            tim.clear()
        )

proc startRegisteredTests*() =
    var curTestSuite = 0
    var curTest = 0
    var tim : Timer
    tim = setInterval(0.5, proc() =
        logi "RUNNING"
        logi registeredTests[curTestSuite][curTest].astrepr
        registeredTests[curTestSuite][curTest].code()
        inc curTest
        if curTest == registeredTests[curTestSuite].len:
            inc curTestSuite
            curTest = 0
            if curTestSuite == registeredTests.len:
                tim.clear()
    )
