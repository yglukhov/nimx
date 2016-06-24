import animation

type AnimationRunner* = ref object
    animations*: seq[Animation]
    onAnimationAdded*: proc()
    onAnimationRemoved*: proc()

proc newAnimationRunner*(): AnimationRunner=
    result = new(AnimationRunner)
    result.animations = @[]

proc pushAnimation*(ar: AnimationRunner, a: Animation) =
    # if not a.isNil and not a.tag.isNil:
    a.prepare()
    if not (a in ar.animations):
        if not ar.onAnimationAdded.isNil():
            ar.onAnimationAdded()
        ar.animations.add(a)

proc removeAnimation*(ar: AnimationRunner, a: Animation) =
    for idx, anim in ar.animations:
        if anim == a:
            ar.animations.delete(idx)
            if not ar.onAnimationRemoved.isNil():
                ar.onAnimationRemoved()
            break

proc update*(ar: AnimationRunner, dt: float)=
    var index = 0

    while index < ar.animations.len:
        var anim = ar.animations[index]
        anim.tick(dt)
        inc index

    index = 0
    while index < ar.animations.len:
        var anim = ar.animations[index]
        if anim.finished:
            ar.animations.delete(index)
            if not ar.onAnimationRemoved.isNil():
                ar.onAnimationRemoved()
        else:
            inc index


