import nimx.sdl_window
import nimx.view
import nimx.logging
import nimx.context
import nimx.matrixes
import nimx.button
import nimx.event

const isMobile = defined(ios) or defined(android)

template c*(a: string) = discard

type GameWindow = ref object of SdlWindow

var mainWindow : GameWindow
mainWindow.new()

when isMobile:
    mainWindow.initFullscreen()
else:
    mainWindow.init(newRect(0, 0, 800, 600))

mainWindow.title = "Test MyGame"

let v1 = newView(newRect(20, 20, 100, 100))
mainWindow.addSubview(v1)

let b1 = newButton(newRect(20, 20, 50, 50))
v1.addSubview(b1)

b1.onAction do (e: Event):
    v1.setFrameOrigin(e.position)

b1.title = "hi"

#b1.onAction do ():
#    echo "Hello world!"


var rot = 0.0

method draw(w: GameWindow) =
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

    tmpTransform = oldTransform[]

    tmpTransform.translate(newVector3(w.frame.width/2, w.frame.height/3 * 2, 0))
    tmpTransform.rotateZ(-rot)
    tmpTransform.translate(newVector3(-50, -50, 0))
    c.fillColor = newColor(0.5, 0.5, 0)
    c.drawRoundedRect(newRect(0, 0, 100, 200), 40)
    c.revertTransform(oldTransform)

runUntilQuit()

