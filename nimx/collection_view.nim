import math

import nimx/event
import nimx/gesture_detector
import nimx/types
import nimx/view

import nimx / meta_extensions / [ property_desc, visitors_gen, serializers_gen ]

type
    LayoutDirection* {.pure.} = enum
        ## Defines how items are layed out inside collection view
        LeftToRight
        TopDown

    RangeCache = tuple[dirty: bool, start: int, finish: int]

    CollectionView* = ref object of View
        # public
        viewForItem*:   proc(i: int): View
        numberOfItems*: proc(): int
        offset*: Coord

        # properties
        layoutDirection: LayoutDirection
        layoutWidth:     int
        itemSize:        Size

        # private
        rangeCache:   RangeCache
        scrollOffset: Coord

    CollectionScrollListener = ref object of OnScrollListener
        v: CollectionView
        p: Point

const
    LayoutWidthAuto*: int = 0


proc updateLayout*(v: CollectionView)

proc newCollectionView*(r: Rect, itemSize: Size, layoutDirection: LayoutDirection, layoutWidth: int = LayoutWidthAuto): CollectionView =
    ## CollectionView constructor
    result.new()
    result.layoutDirection = layoutDirection
    result.layoutWidth = layoutWidth
    result.itemSize = itemSize
    result.init(r)

method clipType*(v: CollectionView): ClipType = ctDefaultClip

proc layoutDirection*(v: CollectionView): LayoutDirection = v.layoutDirection
proc itemSize*(v: CollectionView): Size = v.itemSize
proc layoutWidth*(v: CollectionView): int = v.layoutWidth

proc columnCount*(v: CollectionView): int =
    ## Get horizontal number of items which depends on view settings
    var layoutWidth: int = 0
    if v.layoutDirection == LayoutDirection.LeftToRight:
        layoutWidth = if v.layoutWidth == 0: int(v.frame.height / (v.itemSize.height + v.offset)) else: v.layoutWidth
        if layoutWidth == 0: layoutWidth = 1
        return ceil(v.numberOfItems() / layoutWidth).int
    else:
        layoutWidth = if v.layoutWidth == 0: int(v.frame.width / (v.itemSize.width + v.offset)) else: v.layoutWidth
        if layoutWidth == 0: layoutWidth = 1
        return layoutWidth

proc widthFull(v: CollectionView): Coord =
    return (v.itemSize.width + v.offset) * v.columnCount().Coord

proc rowCount*(v: CollectionView): int =
    ## Get vertical number of items
    var layoutWidth: int = 0
    if v.layoutDirection == LayoutDirection.TopDown:
        layoutWidth = if v.layoutWidth == 0: int(v.frame.width / (v.itemSize.width + v.offset)) else: v.layoutWidth
        if layoutWidth == 0: layoutWidth = 1
        return ceil(v.numberOfItems() / layoutWidth).int
    else:
        layoutWidth = if v.layoutWidth == 0: int(v.frame.height / (v.itemSize.height + v.offset)) else: v.layoutWidth
        if layoutWidth == 0: layoutWidth = 1
        return layoutWidth

proc heightFull(v: CollectionView): Coord =
    return (v.itemSize.height + v.offset) * v.rowCount().Coord

proc visibleRectOfItems(v: CollectionView): Rect =
    let visibleTopLeft = newPoint(
            if v.layoutDirection == LayoutDirection.LeftToRight: v.scrollOffset else: 0,
            if v.layoutDirection == LayoutDirection.TopDown: v.scrollOffset else: 0
        )
    return newRect(visibleTopLeft.x, visibleTopLeft.y, v.frame.width, v.frame.height)

proc visibleRangeOfItems(v: CollectionView): RangeCache =
    ## Get range of items that are visible in current view state
    if v.rangeCache.dirty:
        let visibleRect = v.visibleRectOfItems()
        if v.layoutDirection == LayoutDirection.LeftToRight:
            v.rangeCache.start = int(visibleRect.x / v.itemSize.width) * v.rowCount()
            v.rangeCache.finish = min(ceil(visibleRect.width / v.itemSize.width + 1).int * v.rowCount() + v.rangeCache.start, v.numberOfItems() - 1)
        else:
            v.rangeCache.start = int(visibleRect.y / v.itemSize.height) * v.columnCount()
            v.rangeCache.finish = min(ceil(visibleRect.height / v.itemSize.height + 1).int * v.columnCount() + v.rangeCache.start, v.numberOfItems() - 1)

    return v.rangeCache

proc `layoutDirection=`*(v: CollectionView, layoutDirection: LayoutDirection) =
    v.layoutDirection = layoutDirection
    v.rangeCache.dirty = true
    v.scrollOffset = 0

proc `itemSize=`*(v: CollectionView, itemSize: Size) =
    v.itemSize = itemSize
    v.rangeCache.dirty = true
    v.scrollOffset = 0

proc `layoutWidth=`*(v: CollectionView, layoutWidth: int) =
    v.layoutWidth = layoutWidth
    v.rangeCache.dirty = true
    v.scrollOffset = 0

proc pushToCollection(v: CollectionView, s: View) =
    ## Add new subview to collection view
    v.addSubview(s)

proc reloadData(v: CollectionView) =
    if v.numberOfItems.isNil() or v.viewForItem.isNil():
        raise newException(Exception, "`numberOfItems` or `viewForItem` callback[s] are not set for CollectionView")

    let oldCache = v.rangeCache
    let rangeCache = v.visibleRangeOfItems()
    if oldCache.start == rangeCache.start and oldCache.finish == rangeCache.finish and (not oldCache.dirty):
        return
    else:
        while v.subviews.len() > 0:
            v.subviews[0].removeFromSuperview()

        for i in rangeCache.start .. min(v.rangeCache.finish, v.numberOfItems() - 1):
            let newView = v.viewForItem(i)
            newView.setFrameSize(v.itemSize)
            v.pushToCollection(newView)

proc update(v: CollectionView)=
    v.reloadData()
    let r = v.visibleRectOfItems()
    let rangeCache = v.visibleRangeOfItems()
    for i in rangeCache.start .. rangeCache.finish:
        let posX = if v.layoutDirection == LayoutDirection.LeftToRight:
                       -(r.x.int mod v.itemSize.width.int).Coord + ((i - v.rangeCache.start) div v.rowCount()).Coord * (v.itemSize.width + v.offset) + v.offset
                   else:
                       ((i - rangeCache.start) mod v.columnCount()).Coord * (v.itemSize.width + v.offset) + v.offset

        let posY = if v.layoutDirection == LayoutDirection.LeftToRight:
                       ((i - rangeCache.start) mod v.rowCount()).Coord * (v.itemSize.height + v.offset) + v.offset
                   else:
                       -(r.y.int mod v.itemSize.height.int).Coord + ((i - v.rangeCache.start) div v.columnCount()).Coord * (v.itemSize.height + v.offset) + v.offset
        v.subviews[i - rangeCache.start].setFrameOrigin(newPoint(posX, posY))

    v.setNeedsDisplay()

proc updateLayout*(v: CollectionView) =
   v.scrollOffset = 0.0
   v.update()

method init*(v: CollectionView, r: Rect) =
    procCall v.View.init(r)
    v.rangeCache.dirty = true
    v.offset = 2.0
    let scrollListener = new(CollectionScrollListener)
    scrollListener.v = v
    v.addGestureDetector(newScrollGestureDetector(scrollListener))

method onTapDown(ls: CollectionScrollListener, e : var Event) =
    ls.p = newPoint(
        if ls.v.layoutDirection == LayoutDirection.LeftToRight: ls.v.scrollOffset else: 0,
        if ls.v.layoutDirection == LayoutDirection.TopDown: ls.v.scrollOffset else: 0
    )

method onScrollProgress(ls: CollectionScrollListener, dx, dy : float32, e : var Event) =
    if ls.v.layoutDirection == LayoutDirection.LeftToRight:
        ls.v.scrollOffset = min(max(0, ls.p.x - dx), if ls.v.widthFull() - ls.v.frame.width >= 0: ls.v.widthFull() - ls.v.frame.width else: 0)
    else:
        ls.v.scrollOffset = min(max(0, ls.p.y - dy), if ls.v.heightFull() - ls.v.frame.height >= 0: ls.v.heightFull() - ls.v.frame.height else: 0)
    ls.v.update()

method onTapUp(ls: CollectionScrollListener, dx, dy : float32, e : var Event) =
    discard

method onScroll*(v: CollectionView, e: var Event): bool =
    v.scrollOffset += e.offset.y
    if v.layoutDirection == LayoutDirection.LeftToRight:
        v.scrollOffset = clamp(v.scrollOffset, 0, max(v.widthFull() - v.frame.width, 0))
    else:
        v.scrollOffset = clamp(v.scrollOffset, 0, max(v.heightFull() - v.frame.height,0))
    v.update()

method resizeSubviews*(v: CollectionView, oldSize: Size) =
    if not v.numberOfItems.isNil():
        v.update()

CollectionView.properties:
    offset
    layoutDirection
    layoutWidth
    itemSize

const collectionCreator = proc(): RootRef = newCollectionView(zeroRect, zeroSize, LeftToRight)
registerClass(CollectionView, collectionCreator)
genVisitorCodeForView(CollectionView)
genSerializeCodeForView(CollectionView)
