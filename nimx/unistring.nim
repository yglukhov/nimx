
import unicode

proc uniInsert*(dest: var string, src: string, position: int) =
    var r: Rune
    var charPos = 0
    var bytePos = 0
    while charPos < position:
        fastRuneAt(dest, bytePos, r, true)
        inc charPos
    dest.insert(src, bytePos)

proc insert*(dest: var string, position: int, src: string) {.deprecated.} =
    dest.uniInsert(src, position)

proc uniDelete*(subj: var string, start, stop: int) =
    var charPos = 0
    var byteStartPos = 0
    var r: Rune

    while charPos < start:
        fastRuneAt(subj, byteStartPos, r, true)
        inc charPos

    var byteEndPos = byteStartPos
    while charPos <= stop:
        fastRuneAt(subj, byteEndPos, r, true)
        inc charPos

    var bytesToCopy = byteEndPos - byteStartPos
    var i = 0
    while byteEndPos + i < subj.len:
        subj[byteStartPos + i] = subj[byteEndPos + i]
        inc i
    subj.setLen(subj.len - bytesToCopy)


when isMainModule:
    proc testInsert(dest, src: string, pos: int, result: string) =
        var d = dest
        d.uniInsert(src, pos)
        assert(d == result)

    testInsert("123", "56", 0, "56123")
    testInsert("123", "56", 1, "15623")
    testInsert("123", "56", 3, "12356")
    testInsert("абвЙ", "є", 0, "єабвЙ")
    testInsert("абвЙ", "є", 2, "абєвЙ")
    testInsert("абвЙ", "є", 4, "абвЙє")

    proc testDelete(subj: string, start, stop: int, result: string) =
        var s = subj
        s.uniDelete(start, stop)
        assert(s == result)

    testDelete("hi", 0, 0, "i")
    testDelete("bi", 0, 1, "")
    testDelete("bye", 1, 1, "be")
    testDelete("bye", 2, 2, "by")
    testDelete("bye", 1, 2, "b")
    testDelete("asdf", 1, 1, "adf")
    testDelete("абвЙ", 1, 2, "аЙ")


