//
//  BlurRenderer.swift
//  Literoom
//
//  Created by Brennan Andruss on 9/4/25.
//

import Metal

class BlurRenderer: FilterRenderer {
    private let horizontalComputePipelineState: MTLComputePipelineState!
    private let verticalComputePipelineState: MTLComputePipelineState!
    
    private var scratchTexture: MTLTexture?
    private var weightsBuffer: MTLBuffer?
    private var radius: Int = 0
    static let maxRadius: Int = 50
    
    required init(device: any MTLDevice) {
        let library = device.makeDefaultLibrary()!
        let horizontalKernel = library.makeFunction(name: "gaussianBlurHorizontal")!
        let verticalKernel = library.makeFunction(name: "gaussianBlurVertical")!
        do {
            horizontalComputePipelineState = try device.makeComputePipelineState(function: horizontalKernel)
            verticalComputePipelineState = try device.makeComputePipelineState(function: verticalKernel)
        } catch {
            fatalError("Unable to create blur compute pipeline state")
        }
    }
    
    func configureResources(device: any MTLDevice, inTexture: (any MTLTexture)?) {
        // Allocate weights buffer for maxRadius weights and initialize with zeros
        if weightsBuffer == nil {
            weightsBuffer = device.makeBuffer(
                length: (Self.maxRadius + 1) * MemoryLayout<Float>.stride,
                options: []
            )
            
            if let weightsPtr = weightsBuffer?.contents().bindMemory(to: Float.self, capacity: Self.maxRadius + 1) {
                for i in 0...Self.maxRadius {
                    weightsPtr[i] = 0.0
                }
            }
        }
        
        // Create intermediate texture for horizontal pass output
        guard let inTexture else { return }
        
        if scratchTexture == nil ||
            scratchTexture!.width != inTexture.width ||
            scratchTexture!.height != inTexture.height ||
            scratchTexture!.pixelFormat != inTexture.pixelFormat {
            
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: inTexture.width,
                height: inTexture.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            scratchTexture = device.makeTexture(descriptor: descriptor)
        }
    }
    
    func encode(commandBuffer: any MTLCommandBuffer, inTexture: any MTLTexture, outTexture: any MTLTexture) {
        guard let weightsBuffer, let scratchTexture else { return }
        
        guard let horizontalCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Failed to create horizontal blur command encoder")
            return
        }
        
        // Set up thread groups
        let w = horizontalComputePipelineState.threadExecutionWidth
        let h = horizontalComputePipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (inTexture.width + w - 1) / w,
            height: (inTexture.height + h - 1) / h,
            depth: 1
        )
        
        // Configure horizontal pass
        horizontalCommandEncoder.label = "BlurHorizontal"
        horizontalCommandEncoder.setComputePipelineState(horizontalComputePipelineState)
        horizontalCommandEncoder.setTexture(inTexture, index: 0)
        horizontalCommandEncoder.setTexture(scratchTexture, index: 1)
        horizontalCommandEncoder.setBuffer(weightsBuffer, offset: 0, index: 0)
        horizontalCommandEncoder.setBytes(&radius, length: MemoryLayout<Int>.stride, index: 1)
        horizontalCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        horizontalCommandEncoder.endEncoding()
        
        // Configure vertical pass
        guard let verticalCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Failed to create vertical blur command encoder")
            return
        }
        verticalCommandEncoder.label = "BlurVertical"
        verticalCommandEncoder.setComputePipelineState(verticalComputePipelineState)
        verticalCommandEncoder.setTexture(scratchTexture, index: 0)
        verticalCommandEncoder.setTexture(outTexture, index: 1)
        verticalCommandEncoder.setBuffer(weightsBuffer, offset: 0, index: 0)
        verticalCommandEncoder.setBytes(&radius, length: MemoryLayout<Int>.stride, index: 1)
        verticalCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        verticalCommandEncoder.endEncoding()
    }
    
    func update(value radius: Float) {
        // Only update radius and recompute weights when necessary
        guard self.radius != Int(radius) else { return }
        self.radius = Int(radius)
        
        // Recompute weights covered by radius
        guard let weightsBuffer else {
            return
        }
        
        let weightsPtr = weightsBuffer.contents().bindMemory(to: Float.self, capacity: BlurRenderer.maxRadius)
        let sigma = max(0.5, Float(self.radius) / 3.0)
        var sum: Float = 0.0
        
        // Compute unnormalized, symmetric weights
        for i in 0...self.radius {
            let w = expf(-Float(i * i) / (2 * sigma * sigma))
            weightsPtr[i] = w
            sum += (i == 0) ? w : 2 * w
        }
        
        // Normalize weights with sum of weights
        for i in 0...self.radius {
            weightsPtr[i] /= sum
        }
    }
}
