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
        (a01, a02, a03) = (mat[1], mat[2], mat[3]) #a02 = mat[2], a03 = mat[3],
        (a12, a13) = (mat[6], mat[7])
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
        (a01, a02) = (mat[1], mat[2])
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

proc determinant*(mat: Matrix4): Coord =
    # Cache the matrix values (makes for huge speed increases!)
    let
        (a00, a01, a02, a03) = (mat[0], mat[1], mat[2], mat[3])
        (a10, a11, a12, a13) = (mat[4], mat[5], mat[6], mat[7])
        (a20, a21, a22, a23) = (mat[8], mat[9], mat[10], mat[11])
        (a30, a31, a32, a33) = (mat[12], mat[13], mat[14], mat[15])

    return (a30 * a21 * a12 * a03 - a20 * a31 * a12 * a03 - a30 * a11 * a22 * a03 + a10 * a31 * a22 * a03 +
            a20 * a11 * a32 * a03 - a10 * a21 * a32 * a03 - a30 * a21 * a02 * a13 + a20 * a31 * a02 * a13 +
            a30 * a01 * a22 * a13 - a00 * a31 * a22 * a13 - a20 * a01 * a32 * a13 + a00 * a21 * a32 * a13 +
            a30 * a11 * a02 * a23 - a10 * a31 * a02 * a23 - a30 * a01 * a12 * a23 + a00 * a31 * a12 * a23 +
            a10 * a01 * a32 * a23 - a00 * a11 * a32 * a23 - a20 * a11 * a02 * a33 + a10 * a21 * a02 * a33 +
            a20 * a01 * a12 * a33 - a00 * a21 * a12 * a33 - a10 * a01 * a22 * a33 + a00 * a11 * a22 * a33)

proc tryInverse*(mat: Matrix4, dest: var Matrix4): bool =
    # Cache the matrix values (makes for huge speed increases!)
    let
        (a00, a01, a02, a03) = (mat[0], mat[1], mat[2], mat[3])
        (a10, a11, a12, a13) = (mat[4], mat[5], mat[6], mat[7])
        (a20, a21, a22, a23) = (mat[8], mat[9], mat[10], mat[11])
        (a30, a31, a32, a33) = (mat[12], mat[13], mat[14], mat[15])

        b00 = a00 * a11 - a01 * a10
        b01 = a00 * a12 - a02 * a10
        b02 = a00 * a13 - a03 * a10
        b03 = a01 * a12 - a02 * a11
        b04 = a01 * a13 - a03 * a11
        b05 = a02 * a13 - a03 * a12
        b06 = a20 * a31 - a21 * a30
        b07 = a20 * a32 - a22 * a30
        b08 = a20 * a33 - a23 * a30
        b09 = a21 * a32 - a22 * a31
        b10 = a21 * a33 - a23 * a31
        b11 = a22 * a33 - a23 * a32

        d = (b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06)

    # Calculate the determinant
    if d == 0: return false
    result = true

    let invDet = 1 / d

    dest[0] = (a11 * b11 - a12 * b10 + a13 * b09) * invDet
    dest[1] = (-a01 * b11 + a02 * b10 - a03 * b09) * invDet
    dest[2] = (a31 * b05 - a32 * b04 + a33 * b03) * invDet
    dest[3] = (-a21 * b05 + a22 * b04 - a23 * b03) * invDet
    dest[4] = (-a10 * b11 + a12 * b08 - a13 * b07) * invDet
    dest[5] = (a00 * b11 - a02 * b08 + a03 * b07) * invDet
    dest[6] = (-a30 * b05 + a32 * b02 - a33 * b01) * invDet
    dest[7] = (a20 * b05 - a22 * b02 + a23 * b01) * invDet
    dest[8] = (a10 * b10 - a11 * b08 + a13 * b06) * invDet
    dest[9] = (-a00 * b10 + a01 * b08 - a03 * b06) * invDet
    dest[10] = (a30 * b04 - a31 * b02 + a33 * b00) * invDet
    dest[11] = (-a20 * b04 + a21 * b02 - a23 * b00) * invDet
    dest[12] = (-a10 * b09 + a11 * b07 - a12 * b06) * invDet
    dest[13] = (a00 * b09 - a01 * b07 + a02 * b06) * invDet
    dest[14] = (-a30 * b03 + a31 * b01 - a32 * b00) * invDet
    dest[15] = (a20 * b03 - a21 * b01 + a22 * b00) * invDet

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
    let
        (a00, a01, a02, a03) = (mat[0], mat[1], mat[2], mat[3])
        (a10, a11, a12, a13) = (mat[4], mat[5], mat[6], mat[7])
        (a20, a21, a22, a23) = (mat[8], mat[9], mat[10], mat[11])
        (a30, a31, a32, a33) = (mat[12], mat[13], mat[14], mat[15])

        (b00, b01, b02, b03) = (mat2[0], mat2[1], mat2[2], mat2[3])
        (b10, b11, b12, b13) = (mat2[4], mat2[5], mat2[6], mat2[7])
        (b20, b21, b22, b23) = (mat2[8], mat2[9], mat2[10], mat2[11])
        (b30, b31, b32, b33) = (mat2[12], mat2[13], mat2[14], mat2[15])

    dest[0] = b00 * a00 + b01 * a10 + b02 * a20 + b03 * a30;
    dest[1] = b00 * a01 + b01 * a11 + b02 * a21 + b03 * a31;
    dest[2] = b00 * a02 + b01 * a12 + b02 * a22 + b03 * a32;
    dest[3] = b00 * a03 + b01 * a13 + b02 * a23 + b03 * a33;
    dest[4] = b10 * a00 + b11 * a10 + b12 * a20 + b13 * a30;
    dest[5] = b10 * a01 + b11 * a11 + b12 * a21 + b13 * a31;
    dest[6] = b10 * a02 + b11 * a12 + b12 * a22 + b13 * a32;
    dest[7] = b10 * a03 + b11 * a13 + b12 * a23 + b13 * a33;
    dest[8] = b20 * a00 + b21 * a10 + b22 * a20 + b23 * a30;
    dest[9] = b20 * a01 + b21 * a11 + b22 * a21 + b23 * a31;
    dest[10] = b20 * a02 + b21 * a12 + b22 * a22 + b23 * a32;
    dest[11] = b20 * a03 + b21 * a13 + b22 * a23 + b23 * a33;
    dest[12] = b30 * a00 + b31 * a10 + b32 * a20 + b33 * a30;
    dest[13] = b30 * a01 + b31 * a11 + b32 * a21 + b33 * a31;
    dest[14] = b30 * a02 + b31 * a12 + b32 * a22 + b33 * a32;
    dest[15] = b30 * a03 + b31 * a13 + b32 * a23 + b33 * a33;

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
        (x, y, z) = (vec[0], vec[1], vec[2])

        (a00, a01, a02, a03) = (mat[0], mat[1], mat[2], mat[3])
        (a10, a11, a12, a13) = (mat[4], mat[5], mat[6], mat[7])
        (a20, a21, a22, a23) = (mat[8], mat[9], mat[10], mat[11])

    dest[0] = a00; dest[1] = a01; dest[2] = a02; dest[3] = a03;
    dest[4] = a10; dest[5] = a11; dest[6] = a12; dest[7] = a13;
    dest[8] = a20; dest[9] = a21; dest[10] = a22; dest[11] = a23;

    dest[12] = a00 * x + a10 * y + a20 * z + mat[12];
    dest[13] = a01 * x + a11 * y + a21 * z + mat[13];
    dest[14] = a02 * x + a12 * y + a22 * z + mat[14];
    dest[15] = a03 * x + a13 * y + a23 * z + mat[15];

proc translate*(mat: var Matrix4, vec: Vector3) =
    let (x, y, z) = (vec[0], vec[1], vec[2])

    mat[12] = mat[0] * x + mat[4] * y + mat[8] * z + mat[12];
    mat[13] = mat[1] * x + mat[5] * y + mat[9] * z + mat[13];
    mat[14] = mat[2] * x + mat[6] * y + mat[10] * z + mat[14];
    mat[15] = mat[3] * x + mat[7] * y + mat[11] * z + mat[15];


proc scale*(mat: Matrix4, vec: Vector3, dest: var Matrix4) =
    let (x, y, z) = (vec[0], vec[1], vec[2])

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
    let (x, y, z) = (vec[0], vec[1], vec[2])
    mat[0] *= x;
    mat[1] *= x;
    mat[2] *= x;
    mat[3] *= x;
    mat[4] *= y;
    mat[5] *= y;
    mat[6] *= y;
    mat[7] *= y;
    mat[8] *= z;
    mat[9] *= z;
    mat[10] *= z;
    mat[11] *= z;


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

    let s = sin(angle);
    let c = cos(angle);
    let t = 1 - c;

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
    dest[12] = mat[12];
    dest[13] = mat[13];
    dest[14] = mat[14];
    dest[15] = mat[15];

    # Perform rotation-specific matrix multiplication
    dest[0] = a00 * b00 + a10 * b01 + a20 * b02;
    dest[1] = a01 * b00 + a11 * b01 + a21 * b02;
    dest[2] = a02 * b00 + a12 * b01 + a22 * b02;
    dest[3] = a03 * b00 + a13 * b01 + a23 * b02;

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


proc frustum*(dest: var Matrix4, left, right, bottom, top, near, far: Coord) =
    let
        rl = right - left
        tb = top - bottom
        fn = far - near
    dest[0] = (near * 2) / rl;
    dest[1] = 0;
    dest[2] = 0;
    dest[3] = 0;
    dest[4] = 0;
    dest[5] = (near * 2) / tb;
    dest[6] = 0;
    dest[7] = 0;
    dest[8] = (right + left) / rl;
    dest[9] = (top + bottom) / tb;
    dest[10] = -(far + near) / fn;
    dest[11] = -1;
    dest[12] = 0;
    dest[13] = 0;
    dest[14] = -(far * near * 2) / fn;
    dest[15] = 0;

proc perspective*(dest: var Matrix4, fovy, aspect, near, far: Coord) =
    let
        top = near * tan(fovy * PI / 360.0)
        right = top * aspect
    dest.frustum(-right, right, -top, top, near, far)

proc ortho*(dest: var Matrix4, left, right, bottom, top, near, far: Coord) =
    let
        rl = right - left
        tb = top - bottom
        fn = far - near
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
    dest[14] = -(far + near) / fn;
    dest[15] = 1;

proc ortho*(left, right, bottom, top, near, far: Coord): Matrix4 {.noInit.} =
    result.ortho(left, right, bottom, top, near, far)

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
    dest[1] = y0;
    dest[2] = z0;
    dest[3] = 0;
    dest[4] = x1;
    dest[5] = y1;
    dest[6] = z1;
    dest[7] = 0;
    dest[8] = x2;
    dest[9] = y2;
    dest[10] = z2;
    dest[11] = 0;
    dest[12] = -(x0 * eyex + x1 * eyey + x2 * eyez);
    dest[13] = -(y0 * eyex + y1 * eyey + y2 * eyez);
    dest[14] = -(z0 * eyex + z1 * eyey + z2 * eyez);
    dest[15] = 1;

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
