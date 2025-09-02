//
//  Brightness.metal
//  Literoom
//
//  Created by Brennan Andruss on 8/30/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void brightness(texture2d<float, access::read> inTexture     [[ texture(0) ]],
                       texture2d<float, access::write> outTexture   [[ texture(1) ]],
                       constant float& brightness                   [[ buffer(0) ]],
                       uint2 gid                                    [[thread_position_in_grid]])
{
    // Don't read or write outside of the texture
    if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height()))
    {
        return;
    }
    
    float4 color = inTexture.read(gid);
    
    // Add uniform brightness value to each color channel
    color.rgb += brightness;
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    
    outTexture.write(color, gid);
}
