
import sample_registry

import nimx.view
import nimx.font
import nimx.context
import nimx.composition
import nimx.button
import nimx.autotest

import nimx.gesture_detector_newtouch

const welcomeMessage = "Welcome to nimX"

type WelcomeView = ref object of View
    welcomeFont: Font

type CustomControl* = ref object of Control

method init(v: WelcomeView, r: Rect) =
    procCall v.View.init(r)
    let autoTestButton = newButton(newRect(20, 20, 150, 20))
    let secondTestButton = newButton(newRect(20, 50, 150, 20))
    autoTestButton.title = "Start Auto Tests"
    secondTestButton.title = "Second button"
    let tapd = newTapGestureDetector do(tapPoint : Point):
        echo "tap on second button"
        discard
    secondTestButton.addGestureDetector(tapd)
    autoTestButton.onAction do():
        startRegisteredTests()
    secondTestButton.onAction do():
        echo "second click"
    v.addSubview(autoTestButton)
    v.addSubview(secondTestButton)
    let vtapd = newTapGestureDetector do(tapPoint : Point):
        echo "tap on welcome view"
        discard
    v.addGestureDetector(vtapd)
    var cc: CustomControl
    cc.new
    cc.init(newRect(20, 80, 150, 20))
    cc.clickable = true
    cc.backgroundColor = newColor(1.0,0.0,0.0,1.0)
    cc.onAction do():
        echo "custom control clicked"
    v.addSubview(cc)

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
        v.welcomeFont = systemFontOfSize(64)
    gradientComposition.draw(v.bounds)
    let s = v.welcomeFont.sizeOfString(welcomeMessage)
    c.fillColor = whiteColor()
    c.drawText(v.welcomeFont, s.centerInRect(v.bounds), welcomeMessage)

registerSample "Welcome", WelcomeView.new(newRect(0, 0, 100, 100))
