import typetraits

type SampleInfo = tuple[name: string, className: string]

var allSamples* {.threadvar.}: seq[SampleInfo]

template registerSample*(T: typedesc, sampleName: string) =
    allSamples.add((sampleName, name(T)))
    registerClass(T)
