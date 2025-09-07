//
//  Blur.metal
//  Literoom
//
//  Created by Brennan Andruss on 9/4/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void boxBlur(texture2d<float, access::read> inTexture    [[ texture(0) ]],
                    texture2d<float, access::write> outTexture  [[ texture(1) ]],
                    constant float& radius                      [[ buffer(0) ]],
                    uint2 gid                                   [[thread_position_in_grid]])
{
    // Don't read or write outside of the texture
    if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height()))
    {
        return;
    }
    
    float4 sum = float4(0.0);
    uint count = 0;
    
    for (int x = -radius; x <= radius; x++)
    {
        for (int y = -radius; y <= radius; y++)
        {
            int2 coord = int2(gid) + int2(x, y);
            if (coord.x >= 0 && coord.x < inTexture.get_width() &&
                coord.y >= 0 && coord.y < inTexture.get_height())
            {
                sum += inTexture.read(uint2(coord));
                count++;
            }
        }
    }
    
    float4 color = sum / float(count);
    outTexture.write(color, gid);
}
