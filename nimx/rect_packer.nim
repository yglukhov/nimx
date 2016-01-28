
type Rect = tuple[x, y, width, height: int32]

type RectPacker* = ref object
    c1, c2: RectPacker
    rect: Rect
    occupied: bool
    maxX*, maxY*: int32

proc newPacker*(width, height: int32): RectPacker =
    result.new()
    result.rect.width = width
    result.rect.height = height
    result.maxX = -1
    result.maxY = -1

type Point = tuple[x, y: int32]

template hasSpace*(a: Point): bool = a.x >= 0

proc width*(p: RectPacker): int32 = p.rect.width
proc height*(p: RectPacker): int32 = p.rect.height

proc pack*(p: RectPacker, width, height: int32): Point =
    if not p.c1.isNil:
        # We are leaf
        result = p.c1.pack(width, height)
        if result.hasSpace: return
        result = p.c2.pack(width, height)
    else:
        # If we are occupied, return
        # If we are too small, return
        if p.occupied or width > p.rect.width or height > p.rect.height:
            return (-1.int32, -1.int32)

        # If we're just right, accept
        if width == p.rect.width and height == p.rect.height:
            p.occupied = true
            return (p.rect.x, p.rect.y)

        # Otherwise, gotta split this node and create some kids
        p.c1.new()
        p.c2.new()

        # decide which way to split
        let dw = p.rect.width - width
        let dh = p.rect.height - height

        if dw > dh:
            p.c1.rect = (p.rect.x, p.rect.y, width, p.rect.height)
            p.c2.rect = (p.rect.x + width, p.rect.y, p.rect.width - width, p.rect.height)
        else:
            p.c1.rect = (p.rect.x, p.rect.y, p.rect.width, height)
            p.c2.rect = (p.rect.x, p.rect.y + height, p.rect.width, p.rect.height - height)

        # insert into first child we created
        result = p.c1.pack(width, height)

proc packAndGrow*(p: var RectPacker, width, height: int32): Point =
    while true:
        result = p.pack(width, height)
        if result.hasSpace: break
        var newP : RectPacker
        if p.width < p.height and (p.maxX == -1 or p.maxX >= p.width * 2):
            newP = newPacker(p.width * 2, p.height)
            newP.c2.new()
            newP.c2.rect.x = p.width
            newP.c2.rect.width = p.width
            newP.c2.rect.y = 0
            newP.c2.rect.height = p.height
        elif p.maxY == -1 or p.maxY >= p.height * 2:
            newP = newPacker(p.width, p.height * 2)
            newP.c2.new()
            newP.c2.rect.x = 0
            newP.c2.rect.width = p.width
            newP.c2.rect.y = p.height
            newP.c2.rect.height = p.height
        else:
            break
        newP.maxX = p.maxX
        newP.maxY = p.maxY
        newP.c1 = p
        p = newP
