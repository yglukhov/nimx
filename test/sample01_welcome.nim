
import sample_registry

import nimx.view
import nimx.font
import nimx.context
import nimx.gradient

const welcomeMessage = "Welcome to nimX"

type WelcomeView = ref object of View
    welcomeFont: Font

method init(v: WelcomeView, r: Rect) =
    procCall v.View.init(r)
    v.backgroundColor = newGrayColor(0.40)

method draw(v: WelcomeView, r: Rect) =
    #procCall v.View.draw(r)
    let c = currentContext()
    if v.welcomeFont.isNil:
        v.welcomeFont = systemFontOfSize(32)

    var g = newGradient(newGrayColor(0.7), newGrayColor(0.7))
    g.addColorStop(newGrayColor(0.5), 0.3)
    g.addColorStop(newGrayColor(0.7), 0.5)
    g.addColorStop(newGrayColor(0.5), 0.7)
    c.drawHorizontalGradientInRect(g, v.bounds)

    let s = v.welcomeFont.sizeOfString(welcomeMessage)
    c.fillColor = whiteColor()
    c.drawText(v.welcomeFont, s.centerInRect(v.bounds), welcomeMessage)

registerSample "Welcome", WelcomeView.new(newRect(0, 0, 100, 100))
