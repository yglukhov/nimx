import sample_registry
import nimx / [ view, image, context, render_to_image, font ]
import nimx.assets.asset_manager

type ImageSampleView = ref object of View
    image: Image
    generatedImage: Image
    httpImage: Image

method init*(v: ImageSampleView, r: Rect) =
    procCall v.View.init(r)
    loadImageFromURL("http://gravatar.com/avatar/71b7b08fbc2f989a8246913ac608cca9") do(i: Image):
        v.httpImage = i
        v.setNeedsDisplay()

    sharedAssetManager().getAssetAtPath("cat.jpg") do(i: Image, err: string):
        v.image = i
        v.setNeedsDisplay()

proc renderToImage(): Image =
    let r = imageWithSize(newSize(200, 80))
    r.draw do():
        let c = currentContext()
        c.fillColor = newColor(0.5, 0.5, 1)
        c.strokeColor = newColor(1, 0, 0)
        c.strokeWidth = 3
        c.drawRoundedRect(newRect(0, 0, 200, 80), 20)
        c.fillColor = blackColor()
        let font = systemFontOfSize(32)
        c.drawText(font, newPoint(10, 25), "Runtime image")
    result = r

method draw(v: ImageSampleView, r: Rect) =
    if v.generatedImage.isNil:
        v.generatedImage = renderToImage()

    let c = currentContext()

    # Draw cat
    var imageSize = zeroSize
    if not v.image.isNil:
        imageSize = v.image.size
    var imageRect = newRect(zeroPoint, imageSize)
    imageRect.origin = imageSize.centerInRect(v.bounds)

    if not v.image.isNil:
        c.drawImage(v.image, imageRect)

    # Draw generatedImage
    imageRect.origin.x += imageSize.width - 60
    imageRect.origin.y += imageSize.height - 60
    imageRect.size = v.generatedImage.size
    c.drawImage(v.generatedImage, imageRect)

    if not v.httpImage.isNil:
        c.drawImage(v.httpImage, newRect(50, 50, 100, 100))

registerSample(ImageSampleView, "Image")
