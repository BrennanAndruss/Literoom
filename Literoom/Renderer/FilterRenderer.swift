//
//  FilterRenderer.swift
//  Literoom
//
//  Created by Brennan Andruss on 8/31/25.
//

import Metal

protocol FilterRenderer: AnyObject {
    init(device: MTLDevice)
    
    // Each filter encodes its compute pass into the given command buffer
    func encode(commandBuffer: MTLCommandBuffer, inTexture: MTLTexture, outTexture: MTLTexture)
    
    // Each filter passes through a single value from the application to its shader
    func update(value: Float)
}
