{.deprecated.} # Use darwin package instead
{.passL: "-framework AppKit".}

template enableObjC*() =
  ## Should be called in global scope of a nim file to ensure it will be
  ## translated to Objective-C
  block:
    proc dummyWithNoParticularMeaning() {.used, importobjc.}
