import sample_registry
import nimx / [ view, image, context, render_to_image, font ]
import nimx/assets/asset_manager

type ImageSampleView = ref object of View
    image: Image
    generatedImage: Image
    httpImage: Image

method init*(v: ImageSampleView, gfx: GraphicsContext, r: Rect) =
    procCall v.View.init(gfx, r)
    loadImageFromURL("http://gravatar.com/avatar/71b7b08fbc2f989a8246913ac608cca9") do(i: Image):
        v.httpImage = i
        v.setNeedsDisplay()

    sharedAssetManager().getAssetAtPath("cat.jpg") do(i: Image, err: string):
        v.image = i
        v.setNeedsDisplay()

proc renderToImage(gfx: GraphicsContext): Image =
    template fontCtx: untyped = gfx.fontCtx
    let r = imageWithSize(newSize(200, 80))
    draw gfx, r:
        gfx.fillColor = newColor(0.5, 0.5, 1)
        gfx.strokeColor = newColor(1, 0, 0)
        gfx.strokeWidth = 3
        gfx.drawRoundedRect(newRect(0, 0, 200, 80), 20)
        gfx.fillColor = blackColor()
        let font = systemFontOfSize(fontCtx, 32)
        gfx.drawText(font, newPoint(10, 25), "Runtime image")
    result = r

method draw(v: ImageSampleView, r: Rect) =
    template gfx: untyped = v.gfx

    if v.generatedImage.isNil:
        v.generatedImage = renderToImage(gfx)

    # Draw cat
    var imageSize = zeroSize
    if not v.image.isNil:
        imageSize = v.image.size
    var imageRect = newRect(zeroPoint, imageSize)
    imageRect.origin = imageSize.centerInRect(v.bounds)

    if not v.image.isNil:
        gfx.drawImage(v.image, imageRect)

    # Draw generatedImage
    imageRect.origin.x += imageSize.width - 60
    imageRect.origin.y += imageSize.height - 60
    imageRect.size = v.generatedImage.size
    gfx.drawImage(v.generatedImage, imageRect)

    if not v.httpImage.isNil:
        gfx.drawImage(v.httpImage, newRect(50, 50, 100, 100))

registerSample(ImageSampleView, "Image")
