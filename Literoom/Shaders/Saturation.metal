//
//  File.metal
//  Literoom
//
//  Created by Brennan Andruss on 9/1/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void saturation(texture2d<float, access::read> inTexture     [[ texture(0) ]],
                       texture2d<float, access::write> outTexture   [[ texture(1) ]],
                       constant float& saturation                   [[ buffer(0) ]],
                       uint2 gid                                    [[thread_position_in_grid]])
{
    // Don't read or write outside of the texture
    if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height()))
    {
        return;
    }
    
    float4 color = inTexture.read(gid);
    
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float3 gray = float3(luminance);
    color.rgb = mix(gray, color.rgb, saturation);
    
    outTexture.write(color, gid);
}
