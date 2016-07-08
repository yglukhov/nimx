import animation
import times

type AnimationRunner* = ref object
    animations*: seq[Animation]
    onAnimationAdded*: proc()
    onAnimationRemoved*: proc()
    paused: bool

proc newAnimationRunner*(): AnimationRunner=
    result = new(AnimationRunner)
    result.animations = @[]
    result.paused = false

proc pushAnimation*(ar: AnimationRunner, a: Animation) =
    doAssert( not a.isNil(), "Animation is nil")

    a.prepare(epochTime())

    if ar.paused:
        a.pause()

    if not (a in ar.animations):
        ar.animations.add(a)
        if not ar.onAnimationAdded.isNil():
            ar.onAnimationAdded()

proc pauseAnimations*(ar: AnimationRunner, isHard: bool = false)=
    var index = 0
    let animLen = ar.animations.len

    while index < animLen:
        var anim = ar.animations[index]
        anim.pause()

    if isHard:
        ar.paused = true

proc resumeAnimations*(ar: AnimationRunner) =
    var index = 0
    let animLen = ar.animations.len

    while index < animLen:
        var anim = ar.animations[index]
        anim.resume()

    ar.paused = false

proc removeAnimation*(ar: AnimationRunner, a: Animation) =
    for idx, anim in ar.animations:
        if anim == a:
            ar.animations.delete(idx)
            if not ar.onAnimationRemoved.isNil():
                ar.onAnimationRemoved()
            break

proc update*(ar: AnimationRunner)=

    var index = 0
    let animLen = ar.animations.len

    while index < animLen:
        var anim = ar.animations[index]
        if not anim.finished:
            anim.tick(epochTime())
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