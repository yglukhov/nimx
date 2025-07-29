import animation
import times
import logging

type AnimationRunner* = ref object
  animations*: seq[Animation]
  onAnimationAdded*: proc() {.gcsafe.}
  onAnimationRemoved*: proc() {.gcsafe.}
  paused: bool

proc newAnimationRunner*(): AnimationRunner = AnimationRunner()

proc pushAnimation*(ar: AnimationRunner, a: Animation) =
  if a.isNil:
    assert( not a.isNil(), "[AnimationRunner] Animation is nil")
    warn "[AnimationRunner] Animation is nil! "
    return

  a.prepare(epochTime())

  if ar.paused:
    a.pause()

  if a notin ar.animations:
    ar.animations.add(a)
    if not ar.onAnimationAdded.isNil():
      ar.onAnimationAdded()

proc pauseAnimations*(ar: AnimationRunner, isHard: bool = false)=
  if isHard:
    ar.paused = true

  var index = 0
  let animLen = ar.animations.len

  while index < animLen:
    var anim = ar.animations[index]
    anim.pause()
    inc index

proc resumeAnimations*(ar: AnimationRunner) =
  var index = 0
  let animLen = ar.animations.len

  while index < animLen:
    var anim = ar.animations[index]
    anim.resume()
    inc index

  ar.paused = false

proc removeAnimation*(ar: AnimationRunner, a: Animation) =
  for idx, anim in ar.animations:
    if anim == a:
      ar.animations.delete(idx)
      if not ar.onAnimationRemoved.isNil():
        ar.onAnimationRemoved()
      break

proc update*(ar: AnimationRunner) =

  var index = 0
  let animLen = ar.animations.len

  while index < min(animLen, ar.animations.len):
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

proc onDelete*(ar: AnimationRunner) =
  ar.onAnimationRemoved = nil
  ar.onAnimationAdded = nil
