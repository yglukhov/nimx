
import sample_registry

import nimx.view
import nimx.font
import nimx.context

const welcomeMessage = "Welcome to nimX"

type WelcomeView = ref object of View
    welcomeFont: Font

method init(v: WelcomeView, r: Rect) =
    procCall v.View.init(r)
    v.backgroundColor = newGrayColor(0.40)

method draw(v: WelcomeView, r: Rect) =
    procCall v.View.draw(r)
    let c = currentContext()
    if v.welcomeFont.isNil:
        v.welcomeFont = systemFontOfSize(32)
    let s = v.welcomeFont.sizeOfString(welcomeMessage)
    c.fillColor = whiteColor()
    c.drawText(v.welcomeFont, s.centerInRect(v.bounds), welcomeMessage)

registerSample "Welcome", WelcomeView.new(newRect(0, 0, 100, 100))
