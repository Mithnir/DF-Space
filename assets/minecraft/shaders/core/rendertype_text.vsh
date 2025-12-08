#version 150

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:projection.glsl>
#moj_import <minecraft:light.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

out float sphericalVertexDistance;
out float cylindricalVertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;

// width height depth
const ivec3 SHIP_SIZE = ivec3(5, 5, 5);
const vec3 SHIP_CENTER = vec3(SHIP_SIZE) * 0.5;
const int TEX_SIZE = 16;

const float HEX_C1 = 193.0/255.0;
const vec3 SHIP_HEX_COLOR = vec3(HEX_C1, 0.0, 0.0);

const float PI = 3.141593;
const float TWO_PI = 6.283185;

const float TO_RADS = PI/1800.0;

const vec3 QUAD[4] = vec3[](
    vec3(1.0, 1.0, 0.0),
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0)
);

const vec3 NORMALS[6] = vec3[](
    vec3(0.0, 0.0, -1.0),
    vec3(-1.0, 0.0, 0.0),
    vec3(0.0, 0.0, 1.0),
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, -1.0, 0.0)
);

const ivec2 UV_OFFSET[4] = ivec2[](
    ivec2(0, 0),
    ivec2(0, TEX_SIZE),
    ivec2(TEX_SIZE-1, TEX_SIZE),
    ivec2(TEX_SIZE-1, 0)
);

const bool TOP_VERTS[4] = bool[](1, 0, 0, 1);
const bool BOTTOM_VERTS[4] = bool[](0, 1, 1, 0);

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

// decode yaw and pitch from color
void unpackColor(in vec4 color, out float yaw, out float pitch) {
    int r0 = int(color.r*255)<<4;           // red

    int g0 = int(color.g*255)>>4;           // green
    int g1 = int(mod(color.g*255.0, 16.0)); //

    int b0 = int(color.b*255)<<4;           // blue

    // int a0 = int(color.a*255);              // alpha

    // combine parts and convert to radians
    yaw = float(r0+g0)*TO_RADS;
    pitch = float(g0+b0)*TO_RADS;
}

// rotation matrix from yaw (y axis) and pitch (x axis)
mat3 rotateYawPitch(float yaw, float pitch) {
    // precompute sin and cos
    float yc = cos(yaw);
    float ys = sin(yaw);

    float pc = cos(pitch);
    float ps = sin(pitch);

    // combined rotation matrix
    mat3 rr = mat3(
        -yc, 0.0, -ys,
        -ps*ys, pc, ps*yc,
        pc*ys, ps, -pc*yc
    );

    return rr;
}

// calculate vertex position and normal for ship mesh
void shipPosition(out vec3 pos, out vec3 normal) {
    int vertId = gl_VertexID % 4; // vertex in quad
    int quadId = gl_VertexID/4; // quad in ship mesh
    int faceId = quadId % 6; // face in cube
    int cubeId = quadId / 6; // cube in ship mesh

    // construct quad
    vec3 pos_new = QUAD[vertId];

    // orient quad
    pos_new = orientQuad(pos_new, faceId); // 6 quads per cube
    
    // offset cube
    // TODO: fix this
    // ai made this, pretty sure this is completely wrong, will rewrite when i get to it
    ivec3 cube_offset = ivec3(
        cubeId % SHIP_SIZE.x,
        cubeId / (SHIP_SIZE.x * SHIP_SIZE.z) % SHIP_SIZE.y,
        (cubeId / SHIP_SIZE.x) % SHIP_SIZE.z
    );
     // center ship around origin
    pos_new += cube_offset - SHIP_CENTER;
    
    // unpack vertex color into yaw and pitch
    float y;
    float p;
    unpackColor(Color, y, p);
    mat3 rotation_matrix = rotateYawPitch(y, p); // get rotation matrix

    normal = rotation_matrix * NORMALS[faceId]; // rotate normal vector
    pos = rotation_matrix * pos_new + Position; // rotate and translate position
}

bool filterVertex(vec3 hex_key, vec2 uv, int vertId, int data) {
    ivec2 o = ivec2(uv*256.0)-UV_OFFSET[vertId];
    o.x += int(mod(o.x, 2)); // align to even texel (fix for nvidia graphics buffer bug i hope)
    o.x += 2*data; // offset for data lines in texture atlas
    vec4 Id = texelFetch(Sampler0, o, 0);
    return Id.rgb == hex_key;
}

void main() {
    vec4 col = Color * texelFetch(Sampler2, UV2 / 16, 0);

    // compute ship mesh position and normals
    vec3 ship_pos;
    vec3 normal;
    shipPosition(ship_pos, normal); // get mesh position in local space

    vec4 mlight = minecraft_mix_light(Light0_Direction, Light1_Direction, normal, vec4(1.0)); // apply lighting

    // adjust UVs for ship texture atlas
    bool top_half = TOP_VERTS[gl_VertexID % 4]; // top two verts of quad
    vec2 new_uv = vec2(UV0.x, UV0.y+0.0078125*float(top_half)); // 2/256 offset for bottom verts to hide data line

    // select between ship and vanilla data
    float is_ship = float(filterVertex(SHIP_HEX_COLOR, UV0, gl_VertexID % 4, 0)); // check if vertex is part of ship mesh
    vec3 pos = mix(Position, ship_pos, is_ship);
    col = mix(col, mlight, is_ship);
    vec2 uv = mix(UV0, new_uv, is_ship);
    
    // final transformations
    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);

    // apply fog
    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);

    vertexColor = col;
    texCoord0 = uv;
}