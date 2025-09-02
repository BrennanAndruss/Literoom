//
//  FilterRenderer.swift
//  Literoom
//
//  Created by Brennan Andruss on 8/31/25.
//

import Metal

protocol FilterRenderer: AnyObject {
    init(device: MTLDevice)
    
    func encode(commandBuffer: MTLCommandBuffer, inTexture: MTLTexture, outTexture: MTLTexture)
}
