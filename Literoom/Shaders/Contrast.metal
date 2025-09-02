//
//  Contrast.metal
//  Literoom
//
//  Created by Brennan Andruss on 8/31/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void contrast(texture2d<float, access::read> inTexture   [[ texture(0) ]],
                     texture2d<float, access::write> outTexture [[ texture(1) ]],
                     constant float& contrast                   [[ buffer(0) ]],
                     uint2 gid                                  [[thread_position_in_grid]])
{
    // Don't read or write outside of the texture
    if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height()))
    {
        return;
    }
    
    float4 color = inTexture.read(gid);
    
    // Multiply contrast value centered around 0.5 to each color channel
    float factor = (1.0 + contrast);
    color.rgb = (color.rgb - 0.5) * factor + 0.5;
    
    outTexture.write(color, gid);
}
