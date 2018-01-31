import strutils
import sample_registry
import nimx / [ view, timer, text_field, button ]

type TimersSampleView = ref object of View
    timer: Timer
    intervalTextField: TextField

method init(t: TimersSampleView, r: Rect) =
    procCall t.View.init(r)

    discard t.newLabel(newPoint(20, 20), newSize(120, 20), "interval: ")
    let intervalTextField = t.newTextField(newPoint(150, 20), newSize(120, 20), "5")

    discard t.newLabel(newPoint(20, 50), newSize(120, 20), "periodic: ")

    let periodicButton = newCheckbox(newRect(150, 50, 20, 20))
    t.addSubview(periodicButton)

    var firesLabel: TextField

    let startButton = newButton(newRect(20, 80, 100, 20))
    startButton.title = "Start"
    startButton.onAction do():
        t.timer.clear()
        firesLabel.text = "fires: "
        t.timer = newTimer(parseFloat(intervalTextField.text), periodicButton.boolValue, proc() =
            firesLabel.text = firesLabel.text & "O"
            )
    t.addSubview(startButton)

    let clearButton = newButton(newRect(20, 110, 100, 20))
    clearButton.title = "Clear"
    clearButton.onAction do():
        t.timer.clear()
    t.addSubview(clearButton)

    let pauseButton = newButton(newRect(20, 140, 100, 20))
    pauseButton.title = "Pause"
    pauseButton.onAction do():
        if not t.timer.isNil:
            t.timer.pause()
    t.addSubview(pauseButton)

    let resumeButton = newButton(newRect(20, 170, 100, 20))
    resumeButton.title = "Resume"
    resumeButton.onAction do():
        if not t.timer.isNil:
            t.timer.resume()
    t.addSubview(resumeButton)

    let secondsLabel = t.newLabel(newPoint(20, 200), newSize(120, 20), "seconds: ")
    var secs = 0
    setInterval 1.0, proc() =
        inc secs
        if secs >= 10:
            secs = 0
        secondsLabel.text = "seconds: "
        for i in 0 ..< secs:
            secondsLabel.text = secondsLabel.text & "O"

    firesLabel = t.newLabel(newPoint(20, 230), newSize(120, 20), "fires: ")

registerSample(TimersSampleView, "Timers")
