import nimx.view
import nimx.image
import nimx.context
import sample_registry

type ImageSampleView = ref object of View
    image: Image

method draw(v: ImageSampleView, r: Rect) =
    if v.image.isNil:
        v.image = imageWithResource("cat.jpg")
    let c = currentContext()
    let imageSize = v.image.size
    var imageRect = newRect(zeroPoint, imageSize)
    imageRect.origin = imageSize.centerInRect(v.bounds)
    c.drawImage(v.image, imageRect)

registerSample "Image", ImageSampleView.new(newRect(0, 0, 100, 100))
