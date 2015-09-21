

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

# this is a fragment shader, using distance function in polygon.
# TODO: research later
discard """
freprecision highp float;

const int polyLen = 6;
vec2 polygon[12];

varying vec2 position;

bvec2 intersection(vec2 s, vec2 e, vec2 pos, out vec2 result)
{
	bvec2 greater = greaterThanEqual(pos, min(s, e));
	bvec2 less = lessThanEqual(pos, max(s, e));

	vec2 ab = s - e;
  	float a = s.x * e.y - s.y * e.x;

	result = - (a - pos.yx * ab) / ab.yx;

	return bvec2(greater.x && less.x, greater.y && less.y);
}

bool isPointProjectionOnSegment(vec2 a, vec2 b, vec2 p)
{
	vec2 e1 = b - a;
	float recArea = dot(e1, e1);
	vec2 e2 = p - a;
	float val = dot(e1, e2);
	return (val > 0.0 && val < recArea);
}

float distToLine(vec2 pt1, vec2 pt2, vec2 testPt)
{
  	vec2 lineDir = pt2 - pt1;
  	vec2 perpDir = vec2(lineDir.y, -lineDir.x);
  	vec2 dirToPt1 = pt1 - testPt;
  	return abs(dot(normalize(perpDir), dirToPt1));
}

void checkIntersection(vec2 a, vec2 b, inout float minDist, inout bool inside)
{
	vec2 inter;
	bvec2 foundInter = intersection(a, b, position, inter);

	if (any(foundInter))
	{
		if (foundInter.y && inter.x < position.x)
		{
			inside = !inside;
		}

		if (isPointProjectionOnSegment(a, b, position))
		{
			minDist = min(minDist, distToLine(a, b, position));
		}
	}

	minDist = min(minDist, distance(position, a));
}

void main(void)
{
	polygon[0] = vec2(-0.5, 0.5);
	polygon[1] = vec2(0.5, 0.5);
	polygon[2] = vec2(0.5, -0.5);

	polygon[3] = vec2(0.3, -0.);

	polygon[4] = vec2(0.0, -0.4);
	polygon[5] = vec2(-0.5, -0.5);

	float minDist = 10000000.0;
	bool inside = false;

	checkIntersection(polygon[polyLen - 1], polygon[0], minDist, inside);
	for (int i = 0; i < polyLen - 1; ++i)
	{
		checkIntersection(polygon[i], polygon[i+1], minDist, inside);
	}

	if (inside)
	{
		float coef = 13.5;
		if (minDist < 0.1)
		{
			gl_FragColor = vec4(1.0, minDist * coef, 0, 1);
		}
		else
		{
			gl_FragColor = vec4(1.0, minDist * coef, 0, 1);
		}
	}
	else
		gl_FragColor = vec4(0.0, 1, 0, 1);
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
uniform float uAlpha;
varying vec2 vTexCoord;

void main()
{
    gl_FragColor = texture2D(texUnit, vTexCoord);
		gl_FragColor.a *= uAlpha;
}
"""
