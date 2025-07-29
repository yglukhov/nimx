import nimx / [ view, render_to_image, image, types, context ]

proc renderToImage*(v: View, image: SelfContainedImage)=
  image.draw:
    v.recursiveDrawSubviews()

proc screenShot*(v: View):SelfContainedImage=
  var image = imageWithSize(v.bounds.size)
  v.renderToImage(image)
  result = image
