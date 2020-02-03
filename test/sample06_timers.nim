import strutils
import sample_registry
import nimx / [ view, timer, text_field, button, layout ]

type TimersSampleView = ref object of View
    timer: Timer
    intervalTextField: TextField

method init(t: TimersSampleView, r: Rect) =
    procCall t.View.init(r)
    t.makeLayout:
        - Label:
            text: "interval:"
            leading == super + 20
            top == super + 20
            width == 120
            height == 20
        - TextField as intervalTextField:
            text: "5"
            leading == prev.trailing + 20
            top == prev
            width == 120
            height == prev

        - CheckBox as periodicButton:
            title: "periodic"
            leading == super + 20
            top == prev.bottom + 20
            width == 120
            height == 20

        - Button:
            title: "Start"
            leading == super + 20
            top == prev.bottom + 20
            width == 100
            height == 20
            onAction:
                t.timer.clear()
                firesLabel.text = "fires: "
                t.timer = newTimer(parseFloat(intervalTextField.text), periodicButton.boolValue, proc() =
                    firesLabel.text = firesLabel.text & "O"
                    )

        - Button:
            title: "Clear"
            leading == prev
            top == prev.bottom + 10
            size == prev
            onAction:
                t.timer.clear()

        - Button:
            title: "Pause"
            leading == prev
            top == prev.bottom + 10
            size == prev
            onAction:
                if not t.timer.isNil:
                    t.timer.pause()

        - Button:
            title: "Resume"
            leading == prev
            top == prev.bottom + 10
            size == prev
            onAction:
                if not t.timer.isNil:
                    t.timer.resume()



        - Label as secondsLabel:
            text: "seconds: "
            leading == prev
            top == prev.bottom + 10
            width == 120
            height == 20

        - Label as firesLabel:
            text: "fires: "
            leading == prev
            top == prev.bottom + 10
            size == prev

    var secs = 0
    setInterval 1.0, proc() =
        inc secs
        if secs >= 10:
            secs = 0
        secondsLabel.text = "seconds: "
        for i in 0 ..< secs:
            secondsLabel.text = secondsLabel.text & "O"

registerSample(TimersSampleView, "Timers")
