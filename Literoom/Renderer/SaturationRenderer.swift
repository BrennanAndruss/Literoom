//
//  SaturationRenderer.swift
//  Literoom
//
//  Created by Brennan Andruss on 9/1/25.
//

import Metal

class SaturationRenderer: FilterRenderer {
    private let computePipelineState: MTLComputePipelineState!
    private var saturation: Float = 0.0
    
    required init(device: any MTLDevice) {
        let library = device.makeDefaultLibrary()!
        let kernel = library.makeFunction(name: "saturation")!
        do {
            computePipelineState = try device.makeComputePipelineState(function: kernel)
        } catch {
            fatalError("Unable to create saturation compute pipeline state")
        }
    }
    
    func encode(commandBuffer: any MTLCommandBuffer, inTexture: any MTLTexture, outTexture: any MTLTexture) {
        // Configure compute pass
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        commandEncoder.label = "Saturation"
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(inTexture, index: 0)
        commandEncoder.setTexture(outTexture, index: 1)
        commandEncoder.setBytes(&saturation, length: MemoryLayout<Float>.stride, index: 0)
        
        // Set up thread groups
        let w = computePipelineState.threadExecutionWidth
        let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (inTexture.width + w - 1) / w,
            height: (inTexture.height + h - 1) / h,
            depth: 1
        )
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        commandEncoder.endEncoding()
    }
    
    func update(value saturation: Float) {
        self.saturation = saturation
    }
}
