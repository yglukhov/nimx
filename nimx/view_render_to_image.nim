import nimx.view
import nimx.render_to_image
import nimx.image
import nimx.types

proc renderToImage*(v: View, image: SelfContainedImage)=
    image.draw do():
        v.draw(newRect(0, 0, v.bounds.width, v.bounds.height))

proc screenShot*(v: View):SelfContainedImage=
    var image = imageWithSize(v.bounds.size)
    v.renderToImage(image)
    result = image
