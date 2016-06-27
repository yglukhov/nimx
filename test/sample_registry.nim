import typetraits
import nimx.view

type SampleInfo = tuple[name: string, className: string]

var allSamples* = newSeq[SampleInfo]()

proc registerSample*[T](sampleName: string) =
    allSamples.add((sampleName, T.name))
    registerView[T]()
