
type Rect = tuple[x, y, width, height: int32]

type RectPacker* = ref object
    l, r: RectPacker
    rect: Rect
    occupied: bool

proc newPacker*(width, height: int32): RectPacker =
    result.new()
    result.rect.width = width
    result.rect.height = height

type Point = tuple[x, y: int32]

template hasSpace*(a: Point): bool = a.x >= 0


proc pack*(p: RectPacker, width, height: int32): Point =
    if not p.l.isNil:
        # We are leaf
        result = p.l.pack(width, height)
        if result.hasSpace: return
        result = p.r.pack(width, height)
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
        p.l.new()
        p.r.new()

        # decide which way to split
        let dw = p.rect.width - width
        let dh = p.rect.height - height

        if dw > dh:
            p.l.rect = (p.rect.x, p.rect.y, width, p.rect.height)
            p.r.rect = (p.rect.x + width, p.rect.y, p.rect.width - width, p.rect.height)
        else:
            p.l.rect = (p.rect.x, p.rect.y, p.rect.width, height)
            p.r.rect = (p.rect.x, p.rect.y + height, p.rect.width, p.rect.height - height)

        # insert into first child we created
        result = p.l.pack(width, height)

