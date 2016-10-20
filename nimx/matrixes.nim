import types
import math

type Matrix4* = array[16, Coord]
type Matrix3* = array[9, Coord]

type TVector*[I: static[int], T] = array[I, T]
type TVector2*[T] = TVector[2, T]
type TVector3*[T] = TVector[3, T]
type TVector4*[T] = TVector[4, T]

type Vector2* = TVector2[Coord]
type Vector3* = TVector3[Coord]
type Vector4* = TVector4[Coord]

proc newVector*[T](v0, v1 : T): TVector2[T] = [v0, v1]
proc newVector*[T](v0, v1, v2 : T): TVector3[T] = [v0, v1, v2]
proc newVector*[T](v0, v1, v2, v3 : T): TVector3[T] = [v0, v1, v2, v3]

proc newVector2*(x, y: Coord = 0): Vector2 = [x, y]
proc newVector3*(x, y, z: Coord = 0): Vector3 = [x, y, z]
proc newVector4*(x, y, z, w: Coord = 0): Vector4 = [x, y, z, w]

proc length*(v: Vector2): Coord = sqrt(v[0] * v[0] + v[1] * v[1])
proc length*(v: Vector3): Coord = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])

proc clamp*[I: static[int], T](v, minV, maxV: TVector[I, T]): TVector[I, T] =
    for i in 0 ..< I:
        result[i] = clamp[T](result[i], minV[i], maxV[i])

proc normalize*(v: var Vector3) =
    let leng = v.length()
    if leng != 0:
        v[0] /= leng
        v[1] /= leng
        v[2] /= leng

proc normalized*(v: Vector3): Vector3 =
    let leng = v.length()
    if leng != 0:
        result[0] = v[0] / leng
        result[1] = v[1] / leng
        result[2] = v[2] / leng

template x*[I: static[int], T](v: TVector[I, T]): T = v[0]
template y*[I: static[int], T](v: TVector[I, T]): T = v[1]
template z*[I: static[int], T](v: TVector[I, T]): T = v[2]
template w*[I: static[int], T](v: TVector[I, T]): T = v[3]

template `x=`*[I: static[int], T](v: var TVector[I, T], val: T) = v[0] = val
template `y=`*[I: static[int], T](v: var TVector[I, T], val: T) = v[1] = val
template `z=`*[I: static[int], T](v: var TVector[I, T], val: T) = v[2] = val
template `w=`*[I: static[int], T](v: var TVector[I, T], val: T) = v[3] = val

proc `.`*[I: static[int], T](v: TVector[I, T], field: static[string]): TVector[field.len, T] =
    for i, c in field:
        case c
            of 'x': result[i] = v.x
            of 'y': result[i] = v.y
            of 'z': result[i] = v.z
            of 'w': result[i] = v.w
            else: assert(false, "Unknown field: " & $c)

# The following .= doesn't work yet because of Nim bug #3319
discard """
proc `.=`*[I: static[int], T](v: var TVector[I, T], field: static[string], val: TVector[field.len, T]) =
    for i, c in field:
        case c
            of 'x': v.x = val[i]
            of 'y': v.y = val[i]
            of 'z': v.z = val[i]
            of 'w': v.w = val[i]
            else: assert(false, "Unknown field: " & $c)
"""

proc `*`*[I: static[int], T](v: TVector[I, T], scalar: T): TVector[I, T] =
    for i in 0 ..< v.len: result[i] = v[i] * scalar

proc `/`*[I: static[int], T](v: TVector[I, T], scalar: T): TVector[I, T] =
    for i in 0 ..< v.len: result[i] = v[i] / scalar

proc `+`*[I: static[int], T](v: TVector[I, T], scalar: T): TVector[I, T] =
    for i in 0 ..< v.len: result[i] = v[i] + scalar

proc `-`*[I: static[int], T](v: TVector[I, T], scalar: T): TVector[I, T] =
    for i in 0 ..< v.len: result[i] = v[i] - scalar

proc `*=`*[I: static[int], T](v: var TVector[I, T], scalar: T) =
    for i in 0 ..< v.len: v[i] *= scalar

proc `/=`*[I: static[int], T](v: var TVector[I, T], scalar: T) =
    for i in 0 ..< v.len: v[i] /= scalar

proc `+=`*[I: static[int], T](v: var TVector[I, T], scalar: T) =
    for i in 0 ..< v.len: v[i] += scalar

proc `-=`*[I: static[int], T](v: var TVector[I, T], scalar: T) =
    for i in 0 ..< v.len: v[i] -= scalar

proc `*`*[I: static[int], T](v1, v2: TVector[I, T]): TVector[I, T] =
    for i in 0 ..< v1.len: result[i] = v1[i] * v2[i]

proc `/`*[I: static[int], T](v1, v2: TVector[I, T]): TVector[I, T] =
    for i in 0 ..< v1.len: result[i] = v1[i] / v2[i]

proc `+`*[I: static[int], T](v1, v2: TVector[I, T]): TVector[I, T] =
    for i in 0 ..< v1.len: result[i] = v1[i] + v2[i]

proc `-`*[I: static[int], T](v1, v2: TVector[I, T]): TVector[I, T] =
    for i in 0 ..< v1.len: result[i] = v1[i] - v2[i]

proc `*=`*[I: static[int], T](v1: var TVector[I, T], v2: TVector[I, T]) =
    for i in 0 ..< v1.len: v1[i] *= v2[i]

proc `/=`*[I: static[int], T](v1: var TVector[I, T], v2: TVector[I, T]) =
    for i in 0 ..< v1.len: v1[i] /= v2[i]

proc `+=`*[I: static[int], T](v1: var TVector[I, T], v2: TVector[I, T]) =
    for i in 0 ..< v1.len: v1[i] += v2[i]

proc `-=`*[I: static[int], T](v1: var TVector[I, T], v2: TVector[I, T]) =
    for i in 0 ..< v1.len: v1[i] -= v2[i]

proc `-`*[I: static[int], T](v: TVector[I, T]): TVector[I, T] =
    for i in 0 ..< v.len: result[i] = -v[i]

proc `$`*[I: static[int], T](v: TVector[I, T]): string =
    result = "["
    for i in 0 ..< v.len:
        if i != 0: result &= ", "
        result &= $v[i]
    result &= "]"

proc dot*[I: static[int], T](v1, v2: TVector[I, T]): T =
    for i in 0 ..< v1.len: result += v1[i] * v2[i]

proc cross*[T](a, b: TVector3[T]): TVector3[T] =
    [a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0]]

proc loadIdentity*(dest: var Matrix4) =
    dest[0] = 1
    dest[1] = 0
    dest[2] = 0
    dest[3] = 0
    dest[4] = 0
    dest[5] = 1
    dest[6] = 0
    dest[7] = 0
    dest[8] = 0
    dest[9] = 0
    dest[10] = 1
    dest[11] = 0
    dest[12] = 0
    dest[13] = 0
    dest[14] = 0
    dest[15] = 1

proc loadIdentity*(dest: var Matrix3) =
    dest[0] = 1
    dest[1] = 0
    dest[2] = 0
    dest[3] = 0
    dest[4] = 1
    dest[5] = 0
    dest[6] = 0
    dest[7] = 0
    dest[8] = 1

proc transpose*(mat: var Matrix4) =
    let
        a01 = mat[1]
        a02 = mat[2]
        a03 = mat[3]
        a12 = mat[6]
        a13 = mat[7]
        a23 = mat[11]

    mat[1] = mat[4]
    mat[2] = mat[8]
    mat[3] = mat[12]
    mat[4] = a01
    mat[6] = mat[9]
    mat[7] = mat[13]
    mat[8] = a02
    mat[9] = a12
    mat[11] = mat[14]
    mat[12] = a03
    mat[13] = a13
    mat[14] = a23

proc transpose*(mat: var Matrix3) =
    let
        a01 = mat[1]
        a02 = mat[2]
        a12 = mat[5]

    mat[1] = mat[3]
    mat[2] = mat[6]
    mat[3] = a01
    mat[5] = mat[7]
    mat[6] = a02
    mat[7] = a12

proc transposed*(mat: Matrix4): Matrix4 =
    result[0] = mat[0]
    result[1] = mat[4]
    result[2] = mat[8]
    result[3] = mat[12]
    result[4] = mat[1]
    result[5] = mat[5]
    result[6] = mat[9]
    result[7] = mat[13]
    result[8] = mat[2]
    result[9] = mat[6]
    result[10] = mat[10]
    result[11] = mat[14]
    result[12] = mat[3]
    result[13] = mat[7]
    result[14] = mat[11]
    result[15] = mat[15]

template decomposeToLocals(mat: typed, sym: untyped) =
    let
        `sym m00` {.inject.} = mat[0]
        `sym m01` {.inject.} = mat[1]
        `sym m02` {.inject.} = mat[2]
        `sym m03` {.inject.} = mat[3]
        `sym m10` {.inject.} = mat[4]
        `sym m11` {.inject.} = mat[5]
        `sym m12` {.inject.} = mat[6]
        `sym m13` {.inject.} = mat[7]
        `sym m20` {.inject.} = mat[8]
        `sym m21` {.inject.} = mat[9]
        `sym m22` {.inject.} = mat[10]
        `sym m23` {.inject.} = mat[11]
        `sym m30` {.inject.} = mat[12]
        `sym m31` {.inject.} = mat[13]
        `sym m32` {.inject.} = mat[14]
        `sym m33` {.inject.} = mat[15]

proc determinant*(mat: Matrix4): Coord =
    # Cache the matrix values (makes for huge speed increases!)
    decomposeToLocals(mat, a)

    return (am30 * am21 * am12 * am03 - am20 * am31 * am12 * am03 - am30 * am11 * am22 * am03 + am10 * am31 * am22 * am03 +
            am20 * am11 * am32 * am03 - am10 * am21 * am32 * am03 - am30 * am21 * am02 * am13 + am20 * am31 * am02 * am13 +
            am30 * am01 * am22 * am13 - am00 * am31 * am22 * am13 - am20 * am01 * am32 * am13 + am00 * am21 * am32 * am13 +
            am30 * am11 * am02 * am23 - am10 * am31 * am02 * am23 - am30 * am01 * am12 * am23 + am00 * am31 * am12 * am23 +
            am10 * am01 * am32 * am23 - am00 * am11 * am32 * am23 - am20 * am11 * am02 * am33 + am10 * am21 * am02 * am33 +
            am20 * am01 * am12 * am33 - am00 * am21 * am12 * am33 - am10 * am01 * am22 * am33 + am00 * am11 * am22 * am33)

proc tryInverse*(mat: Matrix4, dest: var Matrix4): bool =
    # Cache the matrix values (makes for huge speed increases!)
    decomposeToLocals(mat, a)

    let
        b00 = am00 * am11 - am01 * am10
        b01 = am00 * am12 - am02 * am10
        b02 = am00 * am13 - am03 * am10
        b03 = am01 * am12 - am02 * am11
        b04 = am01 * am13 - am03 * am11
        b05 = am02 * am13 - am03 * am12
        b06 = am20 * am31 - am21 * am30
        b07 = am20 * am32 - am22 * am30
        b08 = am20 * am33 - am23 * am30
        b09 = am21 * am32 - am22 * am31
        b10 = am21 * am33 - am23 * am31
        b11 = am22 * am33 - am23 * am32

        d = (b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06)

    # Calculate the determinant
    if d == 0: return false
    result = true

    let invDet = 1 / d

    dest[0] = (am11 * b11 - am12 * b10 + am13 * b09) * invDet
    dest[1] = (-am01 * b11 + am02 * b10 - am03 * b09) * invDet
    dest[2] = (am31 * b05 - am32 * b04 + am33 * b03) * invDet
    dest[3] = (-am21 * b05 + am22 * b04 - am23 * b03) * invDet
    dest[4] = (-am10 * b11 + am12 * b08 - am13 * b07) * invDet
    dest[5] = (am00 * b11 - am02 * b08 + am03 * b07) * invDet
    dest[6] = (-am30 * b05 + am32 * b02 - am33 * b01) * invDet
    dest[7] = (am20 * b05 - am22 * b02 + am23 * b01) * invDet
    dest[8] = (am10 * b10 - am11 * b08 + am13 * b06) * invDet
    dest[9] = (-am00 * b10 + am01 * b08 - am03 * b06) * invDet
    dest[10] = (am30 * b04 - am31 * b02 + am33 * b00) * invDet
    dest[11] = (-am20 * b04 + am21 * b02 - am23 * b00) * invDet
    dest[12] = (-am10 * b09 + am11 * b07 - am12 * b06) * invDet
    dest[13] = (am00 * b09 - am01 * b07 + am02 * b06) * invDet
    dest[14] = (-am30 * b03 + am31 * b01 - am32 * b00) * invDet
    dest[15] = (am20 * b03 - am21 * b01 + am22 * b00) * invDet

proc inversed*(mat: Matrix4, dest: var Matrix4) =
    if not tryInverse(mat, dest):
        raise newException(Exception, "Determinant is 0")

proc inversed*(mat: Matrix4): Matrix4 {.inline.} =
    inversed(mat, result)

proc tryInverse*(mat: var Matrix4): bool {.inline.} =
    tryInverse(mat, mat)

proc inverse*(mat: var Matrix4) {.inline.} =
    inversed(mat, mat)

proc toRotationMatrix*(mat: Matrix4, dest: var Matrix4) =
    dest[0] = mat[0]
    dest[1] = mat[1]
    dest[2] = mat[2]
    dest[3] = mat[3]
    dest[4] = mat[4]
    dest[5] = mat[5]
    dest[6] = mat[6]
    dest[7] = mat[7]
    dest[8] = mat[8]
    dest[9] = mat[9]
    dest[10] = mat[10]
    dest[11] = mat[11]
    dest[12] = 0
    dest[13] = 0
    dest[14] = 0
    dest[15] = 1

proc toRotationMatrix*(mat: var Matrix4) =
    mat[12] = 0
    mat[13] = 0
    mat[14] = 0
    mat[15] = 1


proc toMatrix3*(mat: Matrix4, dest: var Matrix3) =
    dest[0] = mat[0]
    dest[1] = mat[1]
    dest[2] = mat[2]
    dest[3] = mat[4]
    dest[4] = mat[5]
    dest[5] = mat[6]
    dest[6] = mat[8]
    dest[7] = mat[9]
    dest[8] = mat[10]

proc toInversedMatrix3*(mat: Matrix4, dest: var Matrix3) =
    # Cache the matrix values (makes for huge speed increases!)
    let
        (a00, a01, a02) = (mat[0], mat[1], mat[2])
        (a10, a11, a12) = (mat[4], mat[5], mat[6])
        (a20, a21, a22) = (mat[8], mat[9], mat[10])

        b01 = a22 * a11 - a12 * a21
        b11 = -a22 * a10 + a12 * a20
        b21 = a21 * a10 - a11 * a20

        d = a00 * b01 + a01 * b11 + a02 * b21

    if d == 0:
        assert(false)
        return
    let id = 1 / d;

    dest[0] = b01 * id
    dest[1] = (-a22 * a01 + a02 * a21) * id
    dest[2] = (a12 * a01 - a02 * a11) * id
    dest[3] = b11 * id
    dest[4] = (a22 * a00 - a02 * a20) * id
    dest[5] = (-a12 * a00 + a02 * a10) * id
    dest[6] = b21 * id
    dest[7] = (-a21 * a00 + a01 * a20) * id
    dest[8] = (a11 * a00 - a01 * a10) * id

proc multiply*(mat, mat2: Matrix4, dest: var Matrix4) =
    # Cache the matrix values (makes for huge speed increases!)
    decomposeToLocals(mat, a)
    decomposeToLocals(mat2, b)

    dest[0] = bm00 * am00 + bm01 * am10 + bm02 * am20 + bm03 * am30
    dest[1] = bm00 * am01 + bm01 * am11 + bm02 * am21 + bm03 * am31
    dest[2] = bm00 * am02 + bm01 * am12 + bm02 * am22 + bm03 * am32
    dest[3] = bm00 * am03 + bm01 * am13 + bm02 * am23 + bm03 * am33
    dest[4] = bm10 * am00 + bm11 * am10 + bm12 * am20 + bm13 * am30
    dest[5] = bm10 * am01 + bm11 * am11 + bm12 * am21 + bm13 * am31
    dest[6] = bm10 * am02 + bm11 * am12 + bm12 * am22 + bm13 * am32
    dest[7] = bm10 * am03 + bm11 * am13 + bm12 * am23 + bm13 * am33
    dest[8] = bm20 * am00 + bm21 * am10 + bm22 * am20 + bm23 * am30
    dest[9] = bm20 * am01 + bm21 * am11 + bm22 * am21 + bm23 * am31
    dest[10] = bm20 * am02 + bm21 * am12 + bm22 * am22 + bm23 * am32
    dest[11] = bm20 * am03 + bm21 * am13 + bm22 * am23 + bm23 * am33
    dest[12] = bm30 * am00 + bm31 * am10 + bm32 * am20 + bm33 * am30
    dest[13] = bm30 * am01 + bm31 * am11 + bm32 * am21 + bm33 * am31
    dest[14] = bm30 * am02 + bm31 * am12 + bm32 * am22 + bm33 * am32
    dest[15] = bm30 * am03 + bm31 * am13 + bm32 * am23 + bm33 * am33

proc multiply*(mat: Matrix4, vec: Vector3, dest: var Vector3) =
    let (x, y, z) = (vec[0], vec[1], vec[2])

    dest[0] = mat[0] * x + mat[4] * y + mat[8] * z + mat[12]
    dest[1] = mat[1] * x + mat[5] * y + mat[9] * z + mat[13]
    dest[2] = mat[2] * x + mat[6] * y + mat[10] * z + mat[14]

proc multiply*(mat: Matrix4, vec: Vector4, dest: var Vector4) =
    let (x, y, z, w) = (vec[0], vec[1], vec[2], vec[3])

    dest[0] = mat[0] * x + mat[4] * y + mat[8] * z + mat[12] * w;
    dest[1] = mat[1] * x + mat[5] * y + mat[9] * z + mat[13] * w;
    dest[2] = mat[2] * x + mat[6] * y + mat[10] * z + mat[14] * w;
    dest[3] = mat[3] * x + mat[7] * y + mat[11] * z + mat[15] * w;

proc `*`*(mat, mat2: Matrix4): Matrix4 =
    mat.multiply(mat2, result)

proc `*`*(mat: Matrix4, vec: Vector3): Vector3 =
    mat.multiply(vec, result)

proc `*`*(mat: Matrix4, vec: Vector4): Vector4 =
    mat.multiply(vec, result)


proc translate*(mat: Matrix4, vec: Vector3, dest: var Matrix4) =
    let
        x = vec[0]
        y = vec[1]
        z = vec[2]

        (a00, a01, a02, a03) = (mat[0], mat[1], mat[2], mat[3])
        (a10, a11, a12, a13) = (mat[4], mat[5], mat[6], mat[7])
        (a20, a21, a22, a23) = (mat[8], mat[9], mat[10], mat[11])

    dest[0] = a00; dest[1] = a01; dest[2] = a02; dest[3] = a03;
    dest[4] = a10; dest[5] = a11; dest[6] = a12; dest[7] = a13;
    dest[8] = a20; dest[9] = a21; dest[10] = a22; dest[11] = a23;

    dest[12] = a00 * x + a10 * y + a20 * z + mat[12]
    dest[13] = a01 * x + a11 * y + a21 * z + mat[13]
    dest[14] = a02 * x + a12 * y + a22 * z + mat[14]
    dest[15] = a03 * x + a13 * y + a23 * z + mat[15]

proc translate*(mat: var Matrix4, vec: Vector3) =
    let
        x = vec[0]
        y = vec[1]
        z = vec[2]

    mat[12] = mat[0] * x + mat[4] * y + mat[8] * z + mat[12]
    mat[13] = mat[1] * x + mat[5] * y + mat[9] * z + mat[13]
    mat[14] = mat[2] * x + mat[6] * y + mat[10] * z + mat[14]
    mat[15] = mat[3] * x + mat[7] * y + mat[11] * z + mat[15]


proc scale*(mat: Matrix4, vec: Vector3, dest: var Matrix4) =
    let
        x = vec[0]
        y = vec[1]
        z = vec[2]

    dest[0] = mat[0] * x;
    dest[1] = mat[1] * x;
    dest[2] = mat[2] * x;
    dest[3] = mat[3] * x;
    dest[4] = mat[4] * y;
    dest[5] = mat[5] * y;
    dest[6] = mat[6] * y;
    dest[7] = mat[7] * y;
    dest[8] = mat[8] * z;
    dest[9] = mat[9] * z;
    dest[10] = mat[10] * z;
    dest[11] = mat[11] * z;
    dest[12] = mat[12];
    dest[13] = mat[13];
    dest[14] = mat[14];
    dest[15] = mat[15];

proc scale*(mat: var Matrix4, vec: Vector3) =
    let
        x = vec[0]
        y = vec[1]
        z = vec[2]
    mat[0] *= x
    mat[1] *= x
    mat[2] *= x
    mat[3] *= x
    mat[4] *= y
    mat[5] *= y
    mat[6] *= y
    mat[7] *= y
    mat[8] *= z
    mat[9] *= z
    mat[10] *= z
    mat[11] *= z


proc rotate*(mat: Matrix4, angle: Coord, axis: Vector3, dest: var Matrix4) =
    var (x, y, z) = (axis[0], axis[1], axis[2])
    var len = sqrt(x * x + y * y + z * z)

    if len == 0:
        assert false
        return

    if len != 1:
        len = 1 / len
        x *= len
        y *= len
        z *= len

    let s = sin(angle)
    let c = cos(angle)
    let t = 1 - c

    let
        (a00, a01, a02, a03) = (mat[0], mat[1], mat[2], mat[3])
        (a10, a11, a12, a13) = (mat[4], mat[5], mat[6], mat[7])
        (a20, a21, a22, a23) = (mat[8], mat[9], mat[10], mat[11])

#        a00 = mat[0]; a01 = mat[1]; a02 = mat[2]; a03 = mat[3];
#        a10 = mat[4]; a11 = mat[5]; a12 = mat[6]; a13 = mat[7];
#        a20 = mat[8]; a21 = mat[9]; a22 = mat[10]; a23 = mat[11];

        # Construct the elements of the rotation matrix
        (b00, b01, b02) = (x * x * t + c,       y * x * t + z * s,   z * x * t - y * s)
        (b10, b11, b12) = (x * y * t - z * s,   y * y * t + c,       z * y * t + x * s)
        (b20, b21, b22) = (x * z * t + y * s,   y * z * t - x * s,   z * z * t + c)

    # If the source and destination differ, copy the unchanged last row
    dest[12] = mat[12]
    dest[13] = mat[13]
    dest[14] = mat[14]
    dest[15] = mat[15]

    # Perform rotation-specific matrix multiplication
    dest[0] = a00 * b00 + a10 * b01 + a20 * b02
    dest[1] = a01 * b00 + a11 * b01 + a21 * b02
    dest[2] = a02 * b00 + a12 * b01 + a22 * b02
    dest[3] = a03 * b00 + a13 * b01 + a23 * b02

    dest[4] = a00 * b10 + a10 * b11 + a20 * b12;
    dest[5] = a01 * b10 + a11 * b11 + a21 * b12;
    dest[6] = a02 * b10 + a12 * b11 + a22 * b12;
    dest[7] = a03 * b10 + a13 * b11 + a23 * b12;

    dest[8] = a00 * b20 + a10 * b21 + a20 * b22;
    dest[9] = a01 * b20 + a11 * b21 + a21 * b22;
    dest[10] = a02 * b20 + a12 * b21 + a22 * b22;
    dest[11] = a03 * b20 + a13 * b21 + a23 * b22;

proc rotateX*(mat: Matrix4, angle: Coord, dest: var Matrix4) =
    let
        s = sin(angle)
        c = cos(angle)
        a10 = mat[4]
        a11 = mat[5]
        a12 = mat[6]
        a13 = mat[7]
        a20 = mat[8]
        a21 = mat[9]
        a22 = mat[10]
        a23 = mat[11]

    # If the source and destination differ, copy the unchanged rows
    dest[0] = mat[0];
    dest[1] = mat[1];
    dest[2] = mat[2];
    dest[3] = mat[3];

    dest[12] = mat[12];
    dest[13] = mat[13];
    dest[14] = mat[14];
    dest[15] = mat[15];

    # Perform axis-specific matrix multiplication
    dest[4] = a10 * c + a20 * s;
    dest[5] = a11 * c + a21 * s;
    dest[6] = a12 * c + a22 * s;
    dest[7] = a13 * c + a23 * s;

    dest[8] = a10 * -s + a20 * c;
    dest[9] = a11 * -s + a21 * c;
    dest[10] = a12 * -s + a22 * c;
    dest[11] = a13 * -s + a23 * c;

proc rotateX*(mat: var Matrix4, angle: Coord) =
    let
        s = sin(angle)
        c = cos(angle)
        a10 = mat[4]
        a11 = mat[5]
        a12 = mat[6]
        a13 = mat[7]
        a20 = mat[8]
        a21 = mat[9]
        a22 = mat[10]
        a23 = mat[11]

    # Perform axis-specific matrix multiplication
    mat[4] = a10 * c + a20 * s;
    mat[5] = a11 * c + a21 * s;
    mat[6] = a12 * c + a22 * s;
    mat[7] = a13 * c + a23 * s;

    mat[8] = a10 * -s + a20 * c;
    mat[9] = a11 * -s + a21 * c;
    mat[10] = a12 * -s + a22 * c;
    mat[11] = a13 * -s + a23 * c;


proc rotateY*(mat: Matrix4, angle: Coord, dest: var Matrix4) =
    let
        s = sin(angle)
        c = cos(angle)
        a00 = mat[0]
        a01 = mat[1]
        a02 = mat[2]
        a03 = mat[3]
        a20 = mat[8]
        a21 = mat[9]
        a22 = mat[10]
        a23 = mat[11]

    # If the source and destination differ, copy the unchanged rows
    dest[4] = mat[4];
    dest[5] = mat[5];
    dest[6] = mat[6];
    dest[7] = mat[7];

    dest[12] = mat[12];
    dest[13] = mat[13];
    dest[14] = mat[14];
    dest[15] = mat[15];

    # Perform axis-specific matrix multiplication
    dest[0] = a00 * c + a20 * -s;
    dest[1] = a01 * c + a21 * -s;
    dest[2] = a02 * c + a22 * -s;
    dest[3] = a03 * c + a23 * -s;

    dest[8] = a00 * s + a20 * c;
    dest[9] = a01 * s + a21 * c;
    dest[10] = a02 * s + a22 * c;
    dest[11] = a03 * s + a23 * c;


proc rotateY*(mat: var Matrix4, angle: Coord) =
    let
        s = sin(angle)
        c = cos(angle)
        a00 = mat[0]
        a01 = mat[1]
        a02 = mat[2]
        a03 = mat[3]
        a20 = mat[8]
        a21 = mat[9]
        a22 = mat[10]
        a23 = mat[11]

    # Perform axis-specific matrix multiplication
    mat[0] = a00 * c + a20 * -s;
    mat[1] = a01 * c + a21 * -s;
    mat[2] = a02 * c + a22 * -s;
    mat[3] = a03 * c + a23 * -s;

    mat[8] = a00 * s + a20 * c;
    mat[9] = a01 * s + a21 * c;
    mat[10] = a02 * s + a22 * c;
    mat[11] = a03 * s + a23 * c;


proc rotateZ*(mat: Matrix4, angle: Coord, dest: var Matrix4) =
    let
        s = sin(angle)
        c = cos(angle)
        a00 = mat[0]
        a01 = mat[1]
        a02 = mat[2]
        a03 = mat[3]
        a10 = mat[4]
        a11 = mat[5]
        a12 = mat[6]
        a13 = mat[7]

    # If the source and destination differ, copy the unchanged last row
    dest[8] = mat[8];
    dest[9] = mat[9];
    dest[10] = mat[10];
    dest[11] = mat[11];

    dest[12] = mat[12];
    dest[13] = mat[13];
    dest[14] = mat[14];
    dest[15] = mat[15];

    # Perform axis-specific matrix multiplication
    dest[0] = a00 * c + a10 * s;
    dest[1] = a01 * c + a11 * s;
    dest[2] = a02 * c + a12 * s;
    dest[3] = a03 * c + a13 * s;

    dest[4] = a00 * -s + a10 * c;
    dest[5] = a01 * -s + a11 * c;
    dest[6] = a02 * -s + a12 * c;
    dest[7] = a03 * -s + a13 * c;

proc rotateZ*(mat: var Matrix4, angle: Coord) =
    let
        s = sin(angle)
        c = cos(angle)
        a00 = mat[0]
        a01 = mat[1]
        a02 = mat[2]
        a03 = mat[3]
        a10 = mat[4]
        a11 = mat[5]
        a12 = mat[6]
        a13 = mat[7]

    # Perform axis-specific matrix multiplication
    mat[0] = a00 * c + a10 * s;
    mat[1] = a01 * c + a11 * s;
    mat[2] = a02 * c + a12 * s;
    mat[3] = a03 * c + a13 * s;

    mat[4] = a00 * -s + a10 * c;
    mat[5] = a01 * -s + a11 * c;
    mat[6] = a02 * -s + a12 * c;
    mat[7] = a03 * -s + a13 * c;

proc frustum*(dest: var Matrix4, left, right, bottom, top, nearr, farr: Coord) =
    let
        rl = right - left
        tb = top - bottom
        fn = farr - nearr
    dest[0] = (nearr * 2) / rl;
    dest[1] = 0;
    dest[2] = 0;
    dest[3] = 0;
    dest[4] = 0;
    dest[5] = (nearr * 2) / tb;
    dest[6] = 0;
    dest[7] = 0;
    dest[8] = (right + left) / rl;
    dest[9] = (top + bottom) / tb;
    dest[10] = -(farr + nearr) / fn;
    dest[11] = -1;
    dest[12] = 0;
    dest[13] = 0;
    dest[14] = -(farr * nearr * 2) / fn;
    dest[15] = 0;

proc perspective*(dest: var Matrix4, fovy, aspect, nearr, farr: Coord) =
    # column major version, compatible with maya cameras
    let size = nearr * tan(degToRad(fovy) / 2.0)
    let left = -size
    let right = size
    let bottom = -size / aspect
    let top = size / aspect

    dest.frustum(left, right, bottom, top, nearr, farr)

proc ortho*(dest: var Matrix4, left, right, bottom, top, nearr, farr: Coord) =
    let
        rl = right - left
        tb = top - bottom
        fn = farr - nearr
    dest[0] = 2 / rl;
    dest[1] = 0;
    dest[2] = 0;
    dest[3] = 0;
    dest[4] = 0;
    dest[5] = 2 / tb;
    dest[6] = 0;
    dest[7] = 0;
    dest[8] = 0;
    dest[9] = 0;
    dest[10] = -2 / fn;
    dest[11] = 0;
    dest[12] = -(left + right) / rl;
    dest[13] = -(top + bottom) / tb;
    dest[14] = -(farr + nearr) / fn;
    dest[15] = 1;

proc ortho*(left, right, bottom, top, nearr, farr: Coord): Matrix4 {.noInit.} =
    result.ortho(left, right, bottom, top, nearr, farr)

proc lookAt*(dest: var Matrix4, eye, center, up: Vector3) =
    let
        eyex = eye[0]
        eyey = eye[1]
        eyez = eye[2]
        upx = up[0]
        upy = up[1]
        upz = up[2]
        centerx = center[0]
        centery = center[1]
        centerz = center[2]

    if eyex == centerx and eyey == centery and eyez == centerz:
        dest.loadIdentity()
        return

    var
        z0 = eyex - centerx
        z1 = eyey - centery
        z2 = eyez - centerz

        # normalize (no check needed for 0 because of early return)
        len = 1 / sqrt(z0 * z0 + z1 * z1 + z2 * z2)

    z0 *= len
    z1 *= len
    z2 *= len

    var
        x0 = upy * z2 - upz * z1
        x1 = upz * z0 - upx * z2
        x2 = upx * z1 - upy * z0
    len = sqrt(x0 * x0 + x1 * x1 + x2 * x2)
    if len == 0:
        x0 = 0
        x1 = 0
        x2 = 0
    else:
        len = 1 / len
        x0 *= len
        x1 *= len
        x2 *= len

    var
        y0 = z1 * x2 - z2 * x1
        y1 = z2 * x0 - z0 * x2
        y2 = z0 * x1 - z1 * x0

    len = sqrt(y0 * y0 + y1 * y1 + y2 * y2)
    if len == 0:
        y0 = 0
        y1 = 0
        y2 = 0
    else:
        len = 1 / len
        y0 *= len
        y1 *= len
        y2 *= len

    dest[0] = x0;
    dest[1] = x1;
    dest[2] = x2;
    dest[3] = 0;
    dest[4] = y0;
    dest[5] = y1;
    dest[6] = y2;
    dest[7] = 0;
    dest[8] = z0;
    dest[9] = z1;
    dest[10] = z2;
    dest[11] = 0;
    dest[12] = -(x0 * eyex + x1 * eyey + x2 * eyez);
    dest[13] = -(y0 * eyex + y1 * eyey + y2 * eyez);
    dest[14] = -(z0 * eyex + z1 * eyey + z2 * eyez);
    dest[15] = 1;

proc tryGetTranslationFromModel*(mat: Matrix4, translation: var Vector3): bool =
    if mat[15] == 0: return false
    translation = newVector3(mat[12], mat[13], mat[14]) / mat[15]
    return true

proc tryGetScaleRotationFromModel*(mat: Matrix4, scale: var Vector3, rotation: var Vector4): bool =
    if mat[15] == 0: return false

    var
        row0 = newVector3(mat[0], mat[1], mat[2]) / mat[15]
        row1 = newVector3(mat[4], mat[5], mat[6]) / mat[15]
        row2 = newVector3(mat[8], mat[9], mat[10]) / mat[15]

    # scale skew
    scale[0] = row0.length()
    row0.normalize()

    var skewXY = dot(row0, row1)
    row1 = row1 - row0 * skewXY

    scale[1] = row1.length()
    row1.normalize()
    skewXY /= scale[1]

    var skewXZ = dot(row0, row2)
    row2 = row2 - row0 * skewXZ

    var skewYZ = dot(row1, row2)
    row2 = row2 - row1 * skewYZ

    scale[2] = row2.length()
    row2.normalize()
    skewXZ /= scale[2]
    skewYZ /= scale[2]

    if dot(row0, cross(row1, row2)) < 0:
        scale[0] *= -1
        row0 *= -1
        row1 *= -1
        row2 *= -1

    # rotation
    var s, t, x, y, z, w: float64

    t = row0[0] + row1[1] + row2[2] + 1.0

    if t > 0.0001:
        s = 0.5 / sqrt(t)
        w = 0.25 / s
        x = (row2[1] - row1[2]) * s
        y = (row0[2] - row2[0]) * s
        z = (row1[0] - row0[1]) * s
    elif row0[0] > row1[1] and row0[0] > row2[2]:
        s = sqrt(1.0 + row0[0] - row1[1] - row2[2]) * 2.0
        x = 0.25 * s
        y = (row0[1] + row1[0]) / s
        z = (row0[2] + row2[0]) / s
        w = (row2[1] - row1[2]) / s
    elif row1[1] > row2[2]:
        s = sqrt(1.0 + row1[1] - row0[0] - row2[2]) * 2.0
        x = (row0[1] + row1[0]) / s
        y = 0.25 * s
        z = (row1[2] + row2[1]) / s
        w = (row0[2] - row2[0]) / s
    else :
        s = sqrt(1.0 + row2[2] - row0[0] - row1[1]) * 2.0
        x = (row0[2] + row2[0]) / s
        y = (row1[2] + row2[1]) / s
        z = 0.25 * s
        w = (row1[0] - row0[1]) / s

    rotation = newVector4(x, y, z, w)

    return true

proc transformDirection*(mat: Matrix4, dir: Vector3): Vector3 =
    result.x = dir.x * mat[0] + dir.y * mat[4] + dir.z * mat[8]
    result.y = dir.x * mat[1] + dir.y * mat[5] + dir.z * mat[9]
    result.z = dir.x * mat[2] + dir.y * mat[6] + dir.z * mat[10]

discard """
mat4_t mat4_fromRotationTranslation(quat_t quat, vec3_t vec, mat4_t dest) {
    if (!dest) { dest = mat4_create(NULL); }

    // Quaternion math
    double x = quat[0], y = quat[1], z = quat[2], w = quat[3],
        x2 = x + x,
        y2 = y + y,
        z2 = z + z,

        xx = x * x2,
        xy = x * y2,
        xz = x * z2,
        yy = y * y2,
        yz = y * z2,
        zz = z * z2,
        wx = w * x2,
        wy = w * y2,
        wz = w * z2;

    dest[0] = 1 - (yy + zz);
    dest[1] = xy + wz;
    dest[2] = xz - wy;
    dest[3] = 0;
    dest[4] = xy - wz;
    dest[5] = 1 - (xx + zz);
    dest[6] = yz + wx;
    dest[7] = 0;
    dest[8] = xz + wy;
    dest[9] = yz - wx;
    dest[10] = 1 - (xx + yy);
    dest[11] = 0;
    dest[12] = vec[0];
    dest[13] = vec[1];
    dest[14] = vec[2];
    dest[15] = 1;

    return dest;
}
"""

when isMainModule:
    var v1 = newVector3(1, 2, 3)
    var v2 = newVector3(4, 5, 6)
    doAssert(v1.x == 1)
    doAssert(v2.y == 5)
    v2.z = 10
    doAssert(v2.z == 10)
