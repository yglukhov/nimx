import control
export control
import menu
import composition
import context
import font
import view_event_handling

type PopupButton* = ref object of Control
    mItems: seq[MenuItem]
    mSelectedItem: int

method init*(b: PopupButton, r: Rect) =
    procCall b.Control.init(r)
    b.mItems = newSeq[MenuItem](0)

proc `items=`*(b: PopupButton, items: openarray[string]) =
    b.mItems.setLen(items.len)
    for i, item in items:
        b.mItems[i] = newMenuItem(item)
        let pWorkaroundForJS = proc(i: int): proc() =
            result = proc() =
                b.mSelectedItem = i
                b.sendAction(Event(kind: etUnknown))
                b.setNeedsDisplay()

        b.mItems[i].action = pWorkaroundForJS(i)

var pbComposition = newComposition """
uniform vec4 uFillColorStart;
uniform vec4 uFillColorEnd;

float radius = 5.0;

void compose() {
    float stroke = sdRoundedRect(bounds, radius);
    float fill = sdRoundedRect(insetRect(bounds, 1.0), radius - 1.0);
    float buttonWidth = 20.0;
    float textAreaWidth = bounds.z - buttonWidth;
    vec4 textAreaRect = bounds;
    textAreaRect.z = textAreaWidth;

    vec4 buttonRect = bounds;
    buttonRect.x += textAreaWidth;
    buttonRect.z = buttonWidth;
    drawShape(stroke, newGrayColor(0.78));

    drawShape(sdAnd(fill, sdRect(textAreaRect)), newGrayColor(1.0));

    vec4 buttonColor = gradient(smoothstep(bounds.y, bounds.y + bounds.w, vPos.y),
        uFillColorStart,
        uFillColorEnd);
    drawShape(sdAnd(fill, sdRect(buttonRect)), buttonColor);

    drawShape(sdRegularPolygon(vec2(buttonRect.x + buttonRect.z / 2.0, buttonRect.y + buttonRect.w / 2.0 - 1.0), 4.0, 3, PI/2.0), vec4(1.0));
}
"""

proc drawBecauseNimBug*(b: PopupButton) =
    pbComposition.draw b.bounds:
        setUniform("uFillColorStart", newColor(0.31, 0.60, 0.98))
        setUniform("uFillColorEnd", newColor(0.09, 0.42, 0.88))

method draw(b: PopupButton, r: Rect) =
    b.drawBecauseNimBug()
    let c = currentContext()
    c.fillColor = blackColor()
    let font = systemFont()
    c.drawText(font, newPoint(4, b.bounds.y + (b.bounds.height - font.size) / 2), b.mItems[b.mSelectedItem].title)

method onMouseDown(b: PopupButton, e: var Event): bool =
    result = true
    var menu : Menu
    menu.new()
    menu.items = b.mItems
    menu.popupAtPoint(b, newPoint(0, -b.mSelectedItem.Coord * 20.0))
