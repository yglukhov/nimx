import nimx.view
import nimx.image
import nimx.context
import nimx.render_to_image
import nimx.font
import sample_registry

type ImageSampleView = ref object of View
    image: Image
    generatedImage: Image
    httpImage: Image

method init*(v: ImageSampleView, r: Rect) =
    procCall v.View.init(r)
    loadImageFromURL("http://gravatar.com/avatar/71b7b08fbc2f989a8246913ac608cca9") do(i: SelfContainedImage):
        v.httpImage = i
        v.setNeedsDisplay()

proc renderToImage(): Image =
    result = imageWithSize(newSize(200, 80))
    result.draw do():
        let c = currentContext()
        c.fillColor = newColor(0.5, 0.5, 1)
        c.strokeColor = newColor(1, 0, 0)
        c.strokeWidth = 3
        c.drawRoundedRect(newRect(0, 0, 200, 80), 20)
        c.fillColor = blackColor()
        let font = systemFontOfSize(32)
        c.drawText(font, newPoint(10, 25), "Runtime image")

method draw(v: ImageSampleView, r: Rect) =
    if v.image.isNil:
        v.image = imageWithResource("cat.jpg")

    if v.generatedImage.isNil:
        v.generatedImage = renderToImage()

    let c = currentContext()

    # Draw cat
    let imageSize = v.image.size
    var imageRect = newRect(zeroPoint, imageSize)
    imageRect.origin = imageSize.centerInRect(v.bounds)
    c.drawImage(v.image, imageRect)

    # Draw generatedImage
    imageRect.origin.x += imageSize.width - 60
    imageRect.origin.y += imageSize.height - 60
    imageRect.size = v.generatedImage.size
    c.drawImage(v.generatedImage, imageRect)

    if not v.httpImage.isNil:
        c.drawImage(v.httpImage, newRect(50, 50, 100, 100))

registerSample(ImageSampleView, "Image")
