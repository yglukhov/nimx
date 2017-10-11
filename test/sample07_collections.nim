import sample_registry

import nimx.collection_view
import nimx.image
import nimx.popup_button
import nimx.slider
import nimx.text_field
import nimx.timer
import nimx.types
import nimx.view
import strutils

type CollectionsSampleView = ref object of View

method init(v: CollectionsSampleView, r: Rect) =
    procCall v.View.init(r)

    setTimeout 0.2, proc() =
        let collection = @["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven"]

        let collectionView = newCollectionView(newRect(0, 0, 450, 250), newSize(50, 50), LayoutDirection.LeftToRight)
        collectionView.numberOfItems = proc(): int =
            return collection.len()
        collectionView.viewForItem = proc(i: int): View =
            result = newView(newRect(0, 0, 100, 100))
            discard newLabel(result, newPoint(0, 0), newSize(50, 50), collection[i])
            result.backgroundColor = newColor(1.0, 0.0, 0.0, 0.8)
        collectionView.itemSize = newSize(50, 50)
        collectionView.backgroundColor = newColor(1.0, 1.0, 1.0, 1.0)
        collectionView.updateLayout()

        v.addSubview(collectionView)

        discard newLabel(v, newPoint(470, 5), newSize(100, 10), "Layout direction:")

        let popupDirectionRule = newPopupButton(v, newPoint(470, 20), newSize(100, 20), ["LeftToRight", "TopDown"])
        popupDirectionRule.onAction do():
            collectionView.layoutDirection = popupDirectionRule.selectedIndex().LayoutDirection
            collectionView.updateLayout()

        discard newLabel(v, newPoint(470, 45), newSize(100, 10), "Layout width:")

        let popupLayoutWidth = newPopupButton(v, newPoint(470, 60), newSize(100, 20), ["Auto", "1", "2", "3", "4"])
        popupLayoutWidth.onAction do():
            collectionView.layoutWidth = popupLayoutWidth.selectedIndex()
            collectionView.updateLayout()

        discard newLabel(v, newPoint(470, 85), newSize(100, 10), "Item size:")

        let popupItemSize = newPopupButton(v, newPoint(470, 100), newSize(100, 20), ["50", "100", "150"])
        popupItemSize.onAction do():
            collectionView.itemSize = newSize((50 + 50 * popupItemSize.selectedIndex()).Coord, (50 + 50 * popupItemSize.selectedIndex()).Coord)
            collectionView.updateLayout()

        discard newLabel(v, newPoint(470, 125), newSize(100, 10), "Offset:")

        let offsetField = newTextField(newRect(newPoint(470, 140), newSize(100, 20)))
        offsetField.continuous = true
        offsetField.onAction do():
            var offset = try: parseFloat(offsetField.text) except: 0.0
            collectionView.offset = offset
            collectionView.updateLayout()
        v.addSubview(offsetField)


registerSample(CollectionsSampleView, "Collections")
