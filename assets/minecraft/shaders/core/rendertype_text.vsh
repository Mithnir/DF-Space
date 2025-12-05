#version 150

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:projection.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;
in float Time;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

out float sphericalVertexDistance;
out float cylindricalVertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;

#define HEX_C1 193.0/255.0

const float PI = 3.141593;
const float TWO_PI = 6.283185;

const vec3 quad[4] = vec3[](
    vec3(-0.5, 0.5, 0.0),
    vec3(-0.5, -0.5, 0.0),
    vec3(0.5, -0.5, 0.0),
    vec3(0.5, 0.5, 0.0)
);

    // data blocks
    // 0xFF 0xFF 0xFF 0xFF

    // data distribution
    // yaw pitch offset
    // FFF FFF   FF

    // yaw       | pitch
    // 16 - 4095 | 0
    // 0 - 15    | 256 - 4095
    // 0         | 0 - 255

void unpackColor(in vec4 color, out int yaw, out int pitch) {
    int y1 = int(color.r*255)<<4;
    int y0 = int(color.g*255)>>4;
    int p1 = int(mod(color.g*255.0, 16.0));
    int p0 = int(color.b*255)<<4;

    yaw = y0+y1;
    pitch = p0+p1;
    // color.a;
}

mat4 rotat(vec3 pos, float yaw, float pitch) {
    // pitchition to rename yaw to yitch
    float yc = cos(TWO_PI*float(yaw));
    float ys = sin(TWO_PI*float(yaw));

    float pc = cos(TWO_PI*float(pitch));
    float ps = sin(TWO_PI*float(pitch));

    mat4 rr = mat4(
        -yc, 0.0, -ys, 0.0,
        -ps*ys, pc, ps*yc, 0.0,
        pc*ys, ps, -pc*yc, 0.0,
        0.0, 0.0, 0.0, 1.0
    );

    // mat4 ry = mat4(
    //     -yc, 0.0, -ys, 0.0,
    //     0.0, 1.0, 0.0, 0.0,
    //     ys, 0.0, -yc, 0.0,
    //     0.0, 0.0, 0.0, 1.0
    // );

    // mat4 rp = mat4(
    //     1.0, 0.0, 0.0, 0.0,
    //     0.0, pc, -ps, 0.0,
    //     0.0, ps, pc, 0.0,
    //     0.0, 0.0, 0.0, 1.0
    // );

    // mat4 rr = ry * rp;

    return rr;
}

vec3 calculateNormals(vec3 pos) {
    int vertId = gl_VertexID % 4;
    return vec3(0.0,0.0,0.0);
}

vec3 positionQuad(vec3 pos) {
    // gl_VertexID;
    int vertId = gl_VertexID % 4;
    int quadId = gl_VertexID/4;
    int blockId = gl_VertexID/24;

    // vec3 pos;

    // construct quad
    vec3 pos_new = quad[vertId];

    // orient quad
    // switch (quadId) {
    //     default:
    //         break;
    // };
    
    // offset cube
    pos_new.x += float(quadId)/10.;

    // pos_new = pos_new + pos;

    return pos_new;
}

void main() {
    // vec4 color = texture(Sampler0, UV0);
    vec3 pos = Position;
    vec4 Id = texelFetch(Sampler0, ivec2(17, 17), 0);
    vec4 col = Color * texelFetch(Sampler2, UV2 / 16, 0);
    bool idb = (Id.r == HEX_C1);
    int y;
    int p;
    unpackColor(Color, y, p);
    if (idb)
    {
        pos = (positionQuad(pos));
        // pos += vec3(0.0, 0.0, -1.0);
        pos = (rotat(pos, float(y)/3600.0, float(p)/3600.0) * vec4(pos, 1.0)).xyz + Position;
        // pos += Position;
        col = vec4(1.0);
        // if (Color == vec4(0.0, 0.0, 0.0, 1.0)) {
        //     col.a = 0.0;
        // }

    }
    vec4 mvp = ModelViewMat * vec4(pos, 1.0);
    gl_Position = ProjMat * mvp;

    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);
    vertexColor = col;
    texCoord0 = UV0;
}