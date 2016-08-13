import macros
import nimx.timer
import nimx.app
import nimx.event
import nimx.abstract_window
import nimx.button
import nimx.system_logger

type UITestSuiteStep* = tuple
    code : proc()
    astrepr: string

type UITestSuite* = seq[UITestSuiteStep]

type TestRunnerContext = ref object
    curTest: int
    curTimeout: float

var testRunnerContext : TestRunnerContext
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

macro registeredUiTest*(name: untyped, body: typed): typed =
    result = newStmtList()
    result.add(testSuiteDefinitionWithNameAndBody(name, body))
    result.add(newCall(bindsym "registerTest", name))

when true:
    proc sendMouseEvent*(wnd: Window, p: Point, bs: ButtonState) =
        var evt = newMouseButtonEvent(p, VirtualKey.MouseButtonPrimary, bs)
        evt.window = wnd
        discard mainApplication().handleEvent(evt)

    proc sendMouseDownEvent*(wnd: Window, p: Point) = sendMouseEvent(wnd, p, bsDown)
    proc sendMouseUpEvent*(wnd: Window, p: Point) = sendMouseEvent(wnd, p, bsUp)

    proc findButtonWithTitle*(v: View, t: string): Button =
        if v of Button:
            let btn = Button(v)
            if btn.title == t:
                result = btn
        else:
            for s in v.subviews:
                result = findButtonWithTitle(s, t)
                if not result.isNil: break

    proc quitApplication*() =
        when defined(js) or defined(emscripten) or defined(android):
            # Hopefully we're using nimx automated testing in Firefox
            logi "---AUTO-TEST-QUIT---"
        else:
            quit()

    template waitUntil*(e: bool): typed =
        if not e: dec testRunnerContext.curTest

when false:
    macro tdump(b: typed): typed =
        echo treeRepr(b)

    tdump:
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
    testRunnerContext.new()
    testRunnerContext.curTimeout = 0.5

    var tim : Timer
    tim = setInterval(0.5, proc() =
        logi "RUNNING ", t[testRunnerContext.curTest].astrepr
        t[testRunnerContext.curTest].code()
        inc testRunnerContext.curTest
        if testRunnerContext.curTest == t.len:
            tim.clear()
            testRunnerContext = nil
        )

proc startRegisteredTests*() =
    testRunnerContext.new()
    testRunnerContext.curTimeout = 0.5

    var curTestSuite = 0
    var tim : Timer
    tim = setInterval(0.5, proc() =
        logi "RUNNING ", registeredTests[curTestSuite][testRunnerContext.curTest].astrepr
        registeredTests[curTestSuite][testRunnerContext.curTest].code()
        inc testRunnerContext.curTest
        if testRunnerContext.curTest == registeredTests[curTestSuite].len:
            inc curTestSuite
            testRunnerContext.curTest = 0
            if curTestSuite == registeredTests.len:
                tim.clear()
                testRunnerContext = nil
    )
