//
//  PassThrough.metal
//  Literoom
//
//  Created by Brennan Andruss on 8/30/25.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex
{
    float2 position;
    float2 texCoord;
};

struct VertexOut
{
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexPassThrough(const device Vertex* vertices [[buffer(0)]],
                                   uint vertexID                 [[vertex_id]])
{
    Vertex v = vertices[vertexID];
    
    VertexOut out;
    out.position = float4(v.position, 0, 1);
    out.texCoord = v.texCoord;
    return out;
}

fragment float4 fragmentPassThrough(VertexOut in                [[stage_in]],
                                    texture2d<float> inputTex   [[ texture(0) ]],
                                    sampler inputSampler        [[ sampler(0) ]])
{
    return inputTex.sample(inputSampler, in.texCoord);
}
