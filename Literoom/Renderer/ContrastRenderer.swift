//
//  ContrastRenderer.swift
//  Literoom
//
//  Created by Brennan Andruss on 8/31/25.
//

import Metal

class ContrastRenderer: FilterRenderer {
    private let computePipelineState: MTLComputePipelineState!
    private var contrast: Float = 0.0
    
    required init(device: MTLDevice) {
        let library = device.makeDefaultLibrary()!
        let kernel = library.makeFunction(name: "contrast")!
        do {
            computePipelineState = try device.makeComputePipelineState(function: kernel)
        } catch {
            fatalError("Unable to create contrast compute pipeline state")
        }
    }
    
    func encode(commandBuffer: MTLCommandBuffer, inTexture: MTLTexture, outTexture: MTLTexture) {
        // Configure compute pass
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        commandEncoder.label = "Contrast"
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(inTexture, index: 0)
        commandEncoder.setTexture(outTexture, index: 1)
        commandEncoder.setBytes(&contrast, length: MemoryLayout<Float>.stride, index: 0)
        
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
    
    func update(contrast: Float) {
        self.contrast = contrast
    }
}
