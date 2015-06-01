import nimx.view

type SampleInfo = tuple[name: string, view: View]

var allSamples* = newSeq[SampleInfo]()

proc registerSample*(name: string, view: View) =
    allSamples.add((name, view))
