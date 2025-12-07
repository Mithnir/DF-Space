#version 150

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:projection.glsl>
#moj_import <minecraft:light.glsl>

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
    vec3(1.0, 1.0, 0.0),
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0)
);

const vec3 cube[8] = vec3[](
    vec3(0.0, 0.0, 0.0),
    vec3(1.0, 0.0, 0.0),
    vec3(1.0, 1.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0),
    vec3(1.0, 0.0, 1.0),
    vec3(1.0, 1.0, 1.0),
    vec3(0.0, 1.0, 1.0)
);

vec3 orientQuad(vec3 pos, int quadId) {
    switch(quadId) {
        case 0: return pos; // front
        case 1: return vec3(pos.z, pos.y, 1.0 - pos.x); // right
        case 2: return vec3(1.0 - pos.x, pos.y, 1.0 - pos.z); // back
        case 3: return vec3(1.0 - pos.z, pos.y, pos.x); // left
        case 4: return vec3(pos.x, 1.0 - pos.z, pos.y); // top
        case 5: return vec3(pos.x, pos.z, 1.0 - pos.y); // bottom
        default: return pos;
    }
}

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
    int y1 = int(color.r*255)<<4;           // red
    int y0 = int(color.g*255)>>4;           // split green
    int p1 = int(mod(color.g*255.0, 16.0)); // -
    int p0 = int(color.b*255)<<4;           // blue
    // int o0 = int(color.a*255);              // alpha

    // combine parts to get full values
    yaw = y0+y1;
    pitch = p0+p1;
}

// pitchition to rename yaw to yitch
mat3 rotat(vec3 pos, float yaw, float pitch) {

    // precompute sin and cos
    float yp = TWO_PI*float(yaw);
    float pp = TWO_PI*float(pitch);

    float yc = cos(yp);
    float ys = sin(yp);

    float pc = cos(pp);
    float ps = sin(pp);

    // combined rotation matrix
    mat3 rr = mat3(
        -yc, 0.0, -ys,
        -ps*ys, pc, ps*yc,
        pc*ys, ps, -pc*yc
    );

    // precombined rotation matrices
    // 
    // mat4 ry = mat4(
    //     -yc, 0.0, -ys, 0.0,
    //     0.0, 1.0, 0.0, 0.0,
    //     ys, 0.0, -yc, 0.0,
    //     0.0, 0.0, 0.0, 1.0
    // );
    // 
    // mat4 rp = mat4(
    //     1.0, 0.0, 0.0, 0.0,
    //     0.0, pc, -ps, 0.0,
    //     0.0, ps, pc, 0.0,
    //     0.0, 0.0, 0.0, 1.0
    // );
    // 
    // mat4 rr = ry * rp;

    return rr;
}

vec3 calculateNormals(vec3 pos) {
    int vertId = gl_VertexID % 4;
    return vec3(0.0,0.0,0.0);
}

vec3 positionQuad(vec3 pos) {
    int vertId = gl_VertexID % 4;
    int quadId = gl_VertexID/4;
    // int blockId = gl_VertexID/24;

    // construct quad
    vec3 pos_new = quad[vertId];

    // orient quad
    pos_new = orientQuad(pos_new, quadId % 6); // 6 quads per cube
    
    // offset cube
    pos_new.x += float(quadId / 6);

    return pos_new;
}

void main() {
    // vec4 color = texture(Sampler0, UV0);
    // vec3 pos = Position;
    
    vec4 Id = texelFetch(Sampler0, ivec2(17, 17), 0);
    float idb = float(Id.r == HEX_C1);

    vec4 col = Color * texelFetch(Sampler2, UV2 / 16, 0);
    
    // unpack vertex color into yaw and pitch
    int y;
    int p;
    unpackColor(Color, y, p);

    // compute ship mesh position
    vec3 ship_pos = positionQuad(Position);
    // apply rotation
    ship_pos = rotat(ship_pos, float(y)/3600.0, float(p)/3600.0) * ship_pos + Position;

    // adjust UVs for ship texture atlas
    bool bottom_verts = gl_VertexID % 4 == 1 || gl_VertexID % 4 == 2;
    vec2 new_uv = vec2(UV0.x, UV0.y-0.0078125*float(bottom_verts)); // 2/256 offset for bottom verts to hide data line

    // select between ship and vanilla position
    vec3 pos = mix(Position, ship_pos, idb);
    col = mix(col, vec4(1.0), idb);
    vec2 uv = mix(UV0, new_uv, idb);
    
    // final transformations
    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);

    // apply fog
    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);

    vertexColor = col;
    texCoord0 = uv;
}