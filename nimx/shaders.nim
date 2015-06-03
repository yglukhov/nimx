
import tables
import hashes

type ShaderAttribute2 = enum
    aPosition
    aColor

proc hash*(x: ShaderAttribute2): THash {.inline.} = ord(x)

type NameType = tuple[name, typ: string]
type AttrType = tuple[name: ShaderAttribute2, typ: string]

type EffectImpl = object
    fillDistance: string
    strokeDistance: string
    fillColor: string
    strokeColor: string
    clipDistance: string
    vertexPosition: string
    fillVaryings: string
    attributes: seq[AttrType]
    varyings: seq[NameType]
    vertexShaderUniforms: seq[NameType]
    fragmentShaderUniforms: seq[NameType]

const MVPTransformation2D = EffectImpl(
    vertexPosition: "return modelViewProjectionMatrix * vec4(aPosition.xy, 0, 1);",

    vertexShaderUniforms: @{
        "modelViewProjectionMatrix": "mat4"
    },

    attributes: @{
        aPosition: "vec4"
    }
)

const SolidColorFill = EffectImpl(
    fragmentShaderUniforms: @{
        "fillColor": "vec4"
    },

    fillColor: """
        return fillColor;
    """
)

proc perVertexAttributeInterpolationEffect(attr: ShaderAttribute2, typ: string): EffectImpl =
    result.attributes = @{attr : typ}
    let varyingName = "v" & ($attr)[1 .. ^1]
    result.fillVaryings = varyingName & "=" & $attr & ";"
    result.varyings = @{ varyingName : typ }

const PerVertexColorFill = EffectImpl(
    fillColor: """
        return vColor;
        """
    )

type ShaderCode = object
    vertexShaderCode, fragmentShaderCode: string
    attributes: seq[ShaderAttribute2]

proc makeShaderCodeWithEffects(effects: varargs[EffectImpl]): ShaderCode =
    result.attributes = @[]
    result.vertexShaderCode = ""
    result.fragmentShaderCode = """
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif
"""
    var attrTable = initTable[ShaderAttribute2, string]()

    for e in effects:
        for nt in e.attributes:
            if attrTable.hasKey(nt.name):
                assert(attrTable[nt.name] == nt.typ, "Attribute " & $nt.name &
                    " already defined with type " & attrTable[nt.name] &
                    ". New type: " & nt.typ)
            else:
                attrTable[nt.name] = nt.typ
                result.attributes.add(nt.name)
                result.vertexShaderCode &= "attribute " & nt.typ & " " & $nt.name & ";\n"

    var symTable = initTable[string, string]()
    for e in effects:
        for nt in e.vertexShaderUniforms:
            assert(not symTable.hasKey(nt.name), "Uniform " & nt.name &
                " already defined with type " & symTable[nt.name] &
                ". New type: " & nt.typ)
            symTable[nt.name] = nt.typ
            result.vertexShaderCode &= "uniform " & nt.typ & " " & nt.name & ";\n"

    for e in effects:
        for nt in e.fragmentShaderUniforms:
            assert(not symTable.hasKey(nt.name), "Uniform " & nt.name &
                " already defined with type " & symTable[nt.name] &
                ". New type: " & nt.typ)
            symTable[nt.name] = nt.typ
            result.fragmentShaderCode &= "uniform " & nt.typ & " " & nt.name & ";\n"

    symTable = initTable[string, string]()
    for e in effects:
        for nt in e.varyings:
            assert(not symTable.hasKey(nt.name), "Varying " & nt.name &
                " already defined with type " & symTable[nt.name] &
                ". New type: " & nt.typ)
            symTable[nt.name] = nt.typ
            result.vertexShaderCode &= "varying " & nt.typ & " " & nt.name & ";\n"
            result.fragmentShaderCode &= "varying " & nt.typ & " " & nt.name & ";\n"

    var vertexPositionDefined = false
    var fillDistanceDefined = false
    var strokeDistanceDefined = false
    var fillColorDefined = false
    var strokeColorDefined = false
    for e in effects:
        if not e.vertexPosition.isNil:
            assert(not vertexPositionDefined)
            vertexPositionDefined = true
            result.vertexShaderCode &= "vec4 vertexPosition(){" & e.vertexPosition & "}\n"
        if not e.fillDistance.isNil:
            assert(not fillDistanceDefined)
            fillDistanceDefined = true
            result.fragmentShaderCode &= "float fillDistance(){" & e.fillDistance & "}\n"
        if not e.strokeDistance.isNil:
            assert(not strokeDistanceDefined)
            strokeDistanceDefined = true
            result.fragmentShaderCode &= "float strokeDistance(){" & e.strokeDistance & "}\n"
        if not e.fillColor.isNil:
            assert(not fillColorDefined)
            fillColorDefined = true
            result.fragmentShaderCode &= "vec4 _fc(){" & e.fillColor & "}\n"
        if not e.strokeColor.isNil:
            assert(not strokeColorDefined)
            strokeColorDefined = true
            result.fragmentShaderCode &= "vec4 strokeColor(){" & e.strokeColor & "}\n"

    assert(vertexPositionDefined)
    assert(fillColorDefined or strokeColorDefined)

    result.vertexShaderCode &= "void main(){gl_Position=vertexPosition();"
    result.fragmentShaderCode &= "void main() {\n"

    for e in effects:
        if not e.fillVaryings.isNil:
            result.vertexShaderCode &= e.fillVaryings & "\n"

    if fillDistanceDefined:
        discard
    else:
        if fillColorDefined:
            result.fragmentShaderCode &= "gl_FragColor=_fc();"

    result.vertexShaderCode &= "}"
    result.fragmentShaderCode &= "}"

const roundedRectVertexShader = """
attribute vec4 position;

uniform mat4 modelViewProjectionMatrix;

varying vec2 vertCoord;

void main()
{
    vertCoord = position.xy;
    gl_Position = modelViewProjectionMatrix * position;
}
"""

const roundedRectFragmentShader = """
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif

uniform vec4 fillColor;
uniform vec4 strokeColor;
uniform float radius;
uniform vec4 rect;
uniform float strokeWidth;

varying vec2 vertCoord;

float udRoundBox(vec2 p, vec2 b, float r)
{
    return length(max(abs(p)-b+r,0.0))-r;
}

void main(void)
{
    // setup
    vec2 halfRes = rect.zw * 0.5;

    // compute box
    float outerDist = udRoundBox(vertCoord.xy - rect.xy - halfRes + 0.0, halfRes - fwidth(vertCoord.xy) * 1.0, radius );
    halfRes -= strokeWidth;
    vec2 xy = rect.xy + strokeWidth;
    float innerRadius = max(0.0, radius - strokeWidth);
    float innerDist = udRoundBox(vertCoord.xy - xy - halfRes + 0.0, halfRes - fwidth(vertCoord.xy) * 1.0, innerRadius );

    float outerDelta = fwidth(outerDist) * 0.8;
    float innerDelta = fwidth(innerDist) * 0.8;
    float innerAlpha = smoothstep(1.0 - innerDelta, 1.0 + innerDelta, innerDist);
    float outerAlpha = smoothstep(1.0 - outerDelta, 1.0 + outerDelta, outerDist);
    gl_FragColor = mix(strokeColor, vec4(strokeColor.rgb, 0), outerAlpha);
    gl_FragColor = mix(fillColor, gl_FragColor, innerAlpha);
}
"""

const ellipseFragmentShader = """
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif

uniform vec4 fillColor;
uniform vec4 strokeColor;
uniform vec4 rect;
uniform float strokeWidth;

varying vec2 vertCoord;

void main()
{
    vec2 ab = rect.zw / 2.0;
	vec2 center = rect.xy + ab;
    vec2 pos = vertCoord  - center;
    pos *= pos;
    float outerDist = dot(pos, 1.0 / (ab * ab));

	ab -= strokeWidth / 2.0;
    float innerDist = dot(pos, 1.0 / (ab * ab));
    float outerDelta = fwidth(outerDist) * 0.8;
    float innerDelta = fwidth(innerDist) * 0.8;

    float innerAlpha = smoothstep(1.0 - innerDelta, 1.0 + innerDelta, innerDist);
    float outerAlpha = smoothstep(1.0 - outerDelta, 1.0 + outerDelta, outerDist);

    gl_FragColor = mix(strokeColor, vec4(strokeColor.rgb, 0), outerAlpha);
    gl_FragColor = mix(fillColor, gl_FragColor, innerAlpha);
}

"""

const fontVertexShader = """
attribute vec4 position;

uniform mat4 modelViewProjectionMatrix;

varying vec2 vTexCoord;

void main()
{
    vTexCoord = position.zw;
    gl_Position = modelViewProjectionMatrix * vec4(position.xy, 0, 1);
}
"""

const fontFragmentShader = """
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif

uniform sampler2D texUnit;
uniform vec4 fillColor;

varying vec2 vTexCoord;

void main()
{
    gl_FragColor = vec4(fillColor.rgb, texture2D(texUnit, vTexCoord).w);
}
"""

const maxVertices = 12

const testPolygonVertexShader = """
attribute vec4 position;
//attribute int vertexIndex;

#extension GL_EXT_gpu_shader4 : require

uniform mat4 modelViewProjectionMatrix;
uniform int numberOfVertices;

varying float bariCoords[""" & $maxVertices & """];

void main()
{
    for (int i = 0; i < numberOfVertices; ++i)
    {
        bariCoords[i] = 0.0;
    }
    bariCoords[gl_VertexID] = 1.0;

    gl_Position = modelViewProjectionMatrix * vec4(position.xy, 0, 1);
}
"""

const testPolygonFragmentShader = """
#ifdef GL_ES
precision mediump float;
#extension GL_OES_standard_derivatives : enable
#endif

varying float bariCoords[""" & $maxVertices & """];
uniform int numberOfVertices;

const float edgeWidth = 0.1;

void main()
{
    gl_FragColor = vec4(bariCoords[0], bariCoords[1], bariCoords[2], 1.0);
    for (int i = 0; i < numberOfVertices - 1; ++i)
    {
        if (bariCoords[i] + bariCoords[i + 1] > 1.0 - edgeWidth)
            gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    }

    if (bariCoords[0] + bariCoords[numberOfVertices - 1] > 1.0 - edgeWidth)
        gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);

    for (int i = 0; i < numberOfVertices; ++i)
    {
        if (bariCoords[i] > 0.9) gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
    }
}

"""

const imageVertexShader = """
attribute vec4 position;

uniform mat4 modelViewProjectionMatrix;

varying vec2 vTexCoord;

void main()
{
    vTexCoord = position.zw;
    gl_Position = modelViewProjectionMatrix * vec4(position.xy, 0, 1);
}
"""

const imageFragmentShader = """
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif

uniform sampler2D texUnit;
varying vec2 vTexCoord;

void main()
{
    gl_FragColor = texture2D(texUnit, vTexCoord);
}
"""
