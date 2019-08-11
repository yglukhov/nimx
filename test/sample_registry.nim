import typetraits

type SampleInfo = tuple[name: string, className: string]

var allSamples* = newSeq[SampleInfo]()

template registerSample*(T: typedesc, sampleName: string) =
    allSamples.add((sampleName, name(T)))
    registerClass(T)
