import nimx / [ types, view ]
import grid_drawing
import editor_types

method draw*(v: EditorWorkspace, r: Rect)=
    procCall v.View.draw(r)

    if v.gridSize != zeroSize:
        drawGrid(v.bounds, v.gridSize)


