import nimx.view
import nimx.logging
import nimx.context
import nimx.matrixes
import nimx.button
import nimx.event
import nimx.text_field
import nimx.app
import nimx.resource


when defined js:
    import nimx.js_canvas_window
    type PlatformWindow = JSCanvasWindow
else:
    import nimx.sdl_window
    type PlatformWindow = SdlWindow

const isMobile = defined(ios) or defined(android)

template c*(a: string) = discard

type GameWindow = ref object of PlatformWindow

logi "hello!"

proc startApplication() =
    logi "startApplication!"
    
    var mainWindow : GameWindow
    mainWindow.new()

    when isMobile:
        mainWindow.initFullscreen()
    elif defined js:
        mainWindow.initWithCanvasId("mainCanvas")
    else:
        mainWindow.init(newRect(0, 0, 800, 600))

    mainWindow.title = "Test MyGame"

    let v1 = newView(newRect(20, 20, mainWindow.frame.width - 40, 100))
    mainWindow.addSubview(v1)

    let b1 = newButton(newRect(20, 20, 50, 50))
    v1.addSubview(b1)

    b1.title = "button"
    v1.autoresizingMask = { afFlexibleWidth, afFlexibleMaxY }

    b1.onAction do ():
        echo "Hello world!"

    let t1 = newTextField(newRect(90, 20, v1.bounds.width - 110, 25))
    v1.addSubview(t1)
    t1.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }
    t1.text = "This is a text field"

    let t2 = newTextField(newRect(90, 50, v1.bounds.width - 110, 25))
    v1.addSubview(t2)
    t2.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }
    t2.text = "This is another text field"

    when not defined js:
        runUntilQuit()

var rot = 0.0

method draw(w: GameWindow, r: Rect) =
    let c = currentContext()
    var tmpTransform = c.transform
    tmpTransform.translate(newVector3(w.frame.width/2, w.frame.height/3, 0))
    tmpTransform.rotateZ(rot)
    tmpTransform.translate(newVector3(-50, -50, 0))
    let oldTransform = c.setScopeTransform(tmpTransform)

    rot += 0.03
    c.fillColor = newColor(0, 1, 1)
    c.strokeColor = newColor(0, 0, 0, 1)
    c.strokeWidth = 9.0
    c.drawEllipseInRect(newRect(0, 0, 100, 200))

    tmpTransform = oldTransform.value()

    tmpTransform.translate(newVector3(w.frame.width/2, w.frame.height/3 * 2, 0))
    tmpTransform.rotateZ(-rot)
    tmpTransform.translate(newVector3(-50, -50, 0))
    c.fillColor = newColor(0.5, 0.5, 0)
    c.drawRoundedRect(newRect(0, 0, 100, 200), 40)
    c.revertTransform(oldTransform)

when defined js:
    import dom
    document.onload = proc (e: ref TEvent) =
        startApplication()
        mainApplication().drawWindows()
else:
    startApplication()

