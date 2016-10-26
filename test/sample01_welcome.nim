
import sample_registry

import nimx.view
import nimx.font
import nimx.context
import nimx.composition
import nimx.button
import nimx.autotest

import nimx.gesture_detector_newtouch
import nimx.view_event_handling_new
import nimx.event

const welcomeMessage = "Welcome to nimX" # welcome text on the centre of window.

type WelcomeView = ref object of View # declare the 'View' class as a local class.
    welcomeFont: Font # declare font of 'Font' class as a local font.

type CustomControl* = ref object of Control # declare the 'Control' class as a local class.

method onScroll*(v: CustomControl, e: var Event): bool = 
    echo "custom scroll ", e.offset # output the text in log if scroll the wheel of mouse in the red field.
    result = true

method init(v: WelcomeView, r: Rect) =
    procCall v.View.init(r)
    let autoTestButton = newButton(newRect(20, 20, 150, 20)) # set 'Start Auto Tests' button size.
    let secondTestButton = newButton(newRect(20, 50, 150, 20)) # set 'Second button' size.
    autoTestButton.title = "Start Auto Tests" # set title for 'Start Auto Tests' button.
    secondTestButton.title = "Second button" # set title for 'Second button'.
    let tapd = newTapGestureDetector do(tapPoint : Point): # on tap the 'Second button',
        echo "tap on second button" # output the text in log.
        discard
    secondTestButton.addGestureDetector(tapd) # activate the 'Second button' on tap.
    autoTestButton.onAction do(): # on tap the 'Start Auto Tests' button,
        startRegisteredTests() # launch the tests.
    secondTestButton.onAction do(): # on tap the 'Second button',
        echo "second click" # output the text in log.
    v.addSubview(autoTestButton)
    v.addSubview(secondTestButton)
    let vtapd = newTapGestureDetector do(tapPoint : Point): # on tap the 'Welcome' window,
        echo "tap on welcome view" # output the text in log.
        discard
    v.addGestureDetector(vtapd) # activate tap.
    var cc: CustomControl # new var has 'CustomControl' class function.
    cc.new
    cc.init(newRect(20, 80, 150, 20)) # set custom control field size.
    cc.clickable = true # enable cc var in this field.
    cc.backgroundColor = newColor(1.0,0.0,0.0,1.0) # field of red color.
    cc.onAction do(): # function for the next user's actions:
        echo "custom control clicked" # output this text in log after user has finished to tap/track on the red field.
    let lis = newBaseScrollListener do(e : var Event): # set the 'listener' on tap/track the red field,
        echo "tap down at: ",e.position # output this text in log.
    do(dx, dy : float32, e : var Event): # coordinats of tap/track in current moment on the red field,
        echo "scroll: ",e.position # output the text in log.
    do(dx, dy : float32, e : var Event): # coordinats of tap/finish to track on the red field,
        echo "scroll end at: ",e.position # output this text in log.
    let flingLis = newBaseFlingListener do(vx, vy: float): # set the 'listener' for coordinats of fling on the red field.
        echo "flinged with velo: ",vx, " ",vy # output this text and flinging velocity data in log.
    cc.addGestureDetector(newScrollGestureDetector(lis)) # use 'listening' when user track's or tap's on the red field.
    cc.addGestureDetector(newFlingGestureDetector(flingLis)) # use 'listening' function when user fling's on the red field.
    v.addSubview(cc)
    cc.trackMouseOver(true) # execute when user stops to tap or track

# set the gradient composition of grey colors on the background of Welcome window (written on GLSL).
var gradientComposition = newComposition """
void compose() {
    vec4 color = gradient(smoothstep(bounds.x, bounds.x + bounds.z, vPos.x),
        newGrayColor(0.7),
        0.3, newGrayColor(0.5),
        0.5, newGrayColor(0.7),
        0.7, newGrayColor(0.5),
        newGrayColor(0.7)
    );
    drawShape(sdRect(bounds), color);
}
"""

method draw(v: WelcomeView, r: Rect) =
    let c = currentContext()
    if v.welcomeFont.isNil:
        v.welcomeFont = systemFontOfSize(64) # set the 64th size of font to 'Welcome to nimX" text.
    gradientComposition.draw(v.bounds) # display the color in 'Welcome' window.
    let s = v.welcomeFont.sizeOfString(welcomeMessage)
    c.fillColor = whiteColor() # set white color to 'Welcome to nimX' text.
    c.drawText(v.welcomeFont, s.centerInRect(v.bounds), welcomeMessage) # display the text in the center of window.

registerSample(WelcomeView, "Welcome") # set the text "Welcom" to the tab of welcome window.
