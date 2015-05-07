
import view
import text_field
import tables

type FormView* = ref object of View
    labelsMap: Table[string, int]

proc newFormView*(r: Rect, numberOfFields: int, adjustFrameHeight: bool = true): FormView =
    result.new()
    let fieldHeight = 20.Coord
    var fr = r
    if adjustFrameHeight:
        fr.size.height = fieldHeight * numberOfFields.Coord

    result.init(fr)
    result.labelsMap = initTable[string, int]()
    for i in 0 .. < numberOfFields:
        let label = newLabel(newRect(0, i.Coord * fieldHeight, r.width / 3, fieldHeight))
        result.addSubview(label)
        let value = newTextField(newRect(r.width / 3, i.Coord * fieldHeight, r.width / 3 * 2, fieldHeight))
        result.addSubview(value)

proc labelAtIndex(v: FormView, index: int): TextField = TextField(v.subviews[index * 2])
proc inputAtIndex(v: FormView, index: int): TextField = TextField(v.subviews[index * 2 + 1])
proc inputForLabel(v: FormView, label: string): TextField = v.inputAtIndex(v.labelsMap[label])

proc labelValue*(v: FormView, index: int): string = v.labelAtIndex(index).text

proc setLabel*(v: FormView, index: int, label: string) =
    let oldLabel = v.labelValue(index)
    v.labelsMap.del(oldLabel)
    v.labelsMap[label] = index
    v.labelAtIndex(index).text = label & ":"

proc setValue*(v: FormView, index: int, value: string) =
    v.inputAtIndex(index).text = value

proc setValue*(v: FormView, label: string, value: string) =
    v.inputForLabel(label).text = value

proc newFormView*(r: Rect, fieldNames: openarray[string], adjustFrameHeight: bool = true): FormView =
    result = newFormView(r, fieldNames.len, adjustFrameHeight)
    for i, n in fieldNames:
        result.setLabel(i, n)
        result.setValue(i, "")

proc inputValue*(v: FormView, index: int): string = v.inputAtIndex(index).text
proc inputValue*(v: FormView, label: string): string = v.inputForLabel(label).text

