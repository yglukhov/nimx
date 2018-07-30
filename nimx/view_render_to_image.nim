import nimx/view
import nimx/render_to_image
import nimx/image
import nimx/types

proc renderToImage*(v: View, image: SelfContainedImage)=
    image.draw do():
        v.recursiveDrawSubviews()

proc screenShot*(v: View):SelfContainedImage=
    var image = imageWithSize(v.bounds.size)
    v.renderToImage(image)
    result = image

