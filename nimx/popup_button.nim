import control
export control
import menu
import composition
import context
import font
import view_event_handling

type PopupButton* = ref object of Control
    mItems: seq[MenuItem]
    mSelectedIndex: int

proc newPopupButton(r: Rect): PopupButton =
    result.new()
    result.init(r)

method init*(b: PopupButton, r: Rect) =
    procCall b.Control.init(r)
    b.mSelectedIndex = -1

proc `items=`*(b: PopupButton, items: openarray[string]) =
    let ln = items.len
    b.mItems.setLen(ln)
    if b.mSelectedIndex > ln - 1:
        b.mSelectedIndex = ln - 1
    elif b.mSelectedIndex == -1 and ln > 0:
        b.mSelectedIndex = 0
    for i, item in items:
        let it = item
        closureScope:
            let ii = i
            b.mItems[ii] = newMenuItem(it)
            b.mItems[ii].action = proc() =
                b.mSelectedIndex = ii
                b.sendAction(Event(kind: etUnknown))
                b.setNeedsDisplay()

proc newPopupButton*(parent: View = nil, position: Point = newPoint(0, 0), size: Size = newSize(100, 20), items: openarray[string]=[], selectedIndex: int=0): PopupButton =
    result = newPopupButton(newRect(position.x, position.y, size.width, size.height))
    result.mSelectedIndex = selectedIndex
    result.items = items
    if not isNil(parent):
        parent.addSubview(result)

proc selectedIndex*(b: PopupButton): int = b.mSelectedIndex
  ## Returns selected item index

proc selectedItem*(b: PopupButton): string = b.mItems[b.mSelectedIndex].title

proc `selectedIndex=`*(b: PopupButton, index: int) =
  ## Set selected item manually
  b.mSelectedIndex = index
  b.setNeedsDisplay()

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

method draw(b: PopupButton, r: Rect) =
    pbComposition.draw b.bounds:
        setUniform("uFillColorStart", newColor(0.31, 0.60, 0.98))
        setUniform("uFillColorEnd", newColor(0.09, 0.42, 0.88))
    if b.mSelectedIndex >= 0 and b.mSelectedIndex < b.mItems.len:
        let c = currentContext()
        c.fillColor = blackColor()
        let font = systemFont()
        c.drawText(font, newPoint(4, b.bounds.y + (b.bounds.height - font.height) / 2), b.mItems[b.mSelectedIndex].title)

method onTouchEv(b: PopupButton, e: var Event): bool =
    if b.mItems.len > 0:
        case e.buttonState
        of bsDown:
            var menu : MenuItem
            menu.new()
            menu.items = b.mItems
            menu.popupAtPoint(b, newPoint(0, -b.mSelectedIndex.Coord * 20.0), newSize(b.bounds.size.width, 20.0))
        else: discard
