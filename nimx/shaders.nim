
const vertexShader = """
attribute vec4 position;

uniform mat4 modelViewProjectionMatrix;

void main()
{
    gl_Position = modelViewProjectionMatrix * position;
}
"""

const fragmentShader = """
#ifdef GL_ES
precision mediump float;
#endif

uniform vec4 fillColor;

void main()
{
	gl_FragColor = fillColor;
}
"""

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

const gradientVertexShader = """
attribute vec2 position;
attribute vec4 color;

uniform mat4 modelViewProjectionMatrix;

varying vec4 vColor;

void main()
{
    vColor = color;
    //vColor = vec4(0, 0.2, 0, 1);
    gl_Position = modelViewProjectionMatrix * vec4(position, 0, 1);
}
"""

const gradientFragmentShader = """
#ifdef GL_ES
precision mediump float;
#endif

varying vec4 vColor;

void main()
{
    gl_FragColor = vColor;
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
