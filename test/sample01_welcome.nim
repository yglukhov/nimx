
import sample_registry

import nimx.view
import nimx.font
import nimx.context
import nimx.composition
import nimx.button
import nimx.autotest

const welcomeMessage = "Welcome to nimX"

type WelcomeView = ref object of View
    welcomeFont: Font

method init(v: WelcomeView, r: Rect) =
    procCall v.View.init(r)
    let autoTestButton = newButton(newRect(20, 20, 150, 20))
    autoTestButton.title = "Start Auto Tests"
    autoTestButton.onAction do():
        startRegisteredTests()
    v.addSubview(autoTestButton)

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
        v.welcomeFont = systemFontOfSize(32)
    gradientComposition.draw(v.bounds)
    let s = v.welcomeFont.sizeOfString(welcomeMessage)
    c.fillColor = whiteColor()
    c.drawText(v.welcomeFont, s.centerInRect(v.bounds), welcomeMessage)

registerSample "Welcome", WelcomeView.new(newRect(0, 0, 100, 100))
