import view

type
    Window* = ref object of View
        gfx*: GraphicsContext
        firstResponder*: View       ## handler of untargeted (keyboard and menu) input
        animationRunners*: seq[AnimationRunner]
        needsDisplay*: bool
        needsLayout*: bool
        mouseOverListeners*: seq[View]
        pixelRatio*: float32
        viewportPixelRatio*: float32
        mActiveBgColor*: Color
        layoutSolver*: Solver
        onClose*: proc()
        mCurrentTouches*: TableRef[int, View]
        mAnimationEnabled*: bool
