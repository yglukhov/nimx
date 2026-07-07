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

method init*(b: PopupButton) =
  procCall b.Control.init()
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

proc selectedIndex*(b: PopupButton): int = b.mSelectedIndex
  ## Returns selected item index

proc selectedItem*(b: PopupButton): string = b.mItems[b.mSelectedIndex].title

proc `selectedIndex=`*(b: PopupButton, index: int) =
  ## Set selected item manually
  b.mSelectedIndex = index
  b.setNeedsDisplay()

const pbComposition = newComposition """
const radius: f32 = 5.0;
fn compose() {
  let stroke = sdRoundedRectAt(uni.bounds, radius);
  let fill = sdRoundedRectAt(insetRect(uni.bounds, 1.0), radius - 1.0);
  let buttonWidth = 20.0;
  let textAreaWidth = uni.bounds.z - buttonWidth;
  var textAreaRect = uni.bounds;
  textAreaRect.z = textAreaWidth;
  var buttonRect = uni.bounds;
  buttonRect.x += textAreaWidth;
  buttonRect.z = buttonWidth;
  drawShape(stroke, newGrayColor(0.78));
  drawShape(sdAnd(fill, sdRectAt(textAreaRect)), newGrayColor(1.0));
  let buttonColor = gradient(smoothstep(uni.bounds.y, uni.bounds.y + uni.bounds.w, vPos.y),
    uni.uFillColorStart,
    uni.uFillColorEnd);
  drawShape(sdAnd(fill, sdRectAt(buttonRect)), buttonColor);
  drawShape(sdRegularPolygonAt(vec2f(buttonRect.x + buttonRect.z / 2.0, buttonRect.y + buttonRect.w / 2.0 - 1.0), 4.0, 3, PI/2.0), vec4f(1.0));
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
