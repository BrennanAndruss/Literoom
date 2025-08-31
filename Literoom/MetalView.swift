//
//  MetalView.swift
//  Literoom
//
//  Created by Brennan Andruss on 8/30/25.
//

import SwiftUI
import MetalKit

struct Vertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
}

struct MetalView: NSViewRepresentable {
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalView
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        
        var renderPipelineState: MTLRenderPipelineState!
        var computePipelineState: MTLComputePipelineState!
        
        var inTexture: MTLTexture!
        var vertexBuffer: MTLBuffer!
        var sampler: MTLSamplerState!
        
        var brightness: Float = 0.0
        
        init(_ parent: MetalView) {
            self.parent = parent
            super.init()
            
            device = MTLCreateSystemDefaultDevice()
            
            configureMetal()
            
            // Create quad to cover the MetalView
            let vertices: [Vertex] = [
                Vertex(position: [-1, -1], texCoord: [0, 1]),
                Vertex(position: [ 1, -1], texCoord: [1, 1]),
                Vertex(position: [-1,  1], texCoord: [0, 0]),
                
                Vertex(position: [-1,  1], texCoord: [0, 0]),
                Vertex(position: [ 1, -1], texCoord: [1, 1]),
                Vertex(position: [ 1,  1], texCoord: [1, 0])
            ]
            
            vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<Vertex>.stride * vertices.count,
                options: []
            )!
            
            // Load sample image
            inTexture = loadTexture(named: "Image1", device: device)
        }
        
        func configureMetal() {
            commandQueue = device.makeCommandQueue()
            
            let library = device.makeDefaultLibrary()!
            let kernel = library.makeFunction(name: "brightness")!
            do {
                computePipelineState = try device.makeComputePipelineState(function: kernel)
            } catch {
                fatalError("Unable to create compute pipeline state")
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexPassThrough")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentPassThrough")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            do {
                renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                fatalError("Unable to create render pipeline state")
            }
            
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.sAddressMode = .clampToEdge
            samplerDescriptor.tAddressMode = .clampToEdge
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable else { return }
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            
            // Create output texture
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: inTexture.width,
                height: inTexture.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            guard let outTexture = device.makeTexture(descriptor: descriptor) else { return }
            
            // Run compute pass
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return
            }
            
            commandEncoder.label = "Brightness"
            commandEncoder.setComputePipelineState(computePipelineState)
            commandEncoder.setTexture(inTexture, index: 0)
            commandEncoder.setTexture(outTexture, index: 1)
            var b = brightness
            commandEncoder.setBytes(&b, length: MemoryLayout<Float>.stride, index: 0)
            
            // Set up thread groups
            let w = computePipelineState.threadExecutionWidth
            let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
            let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (outTexture.width + 1 - 1) / w,
                height: (outTexture.height + h - 1) / h,
                depth: 1
            )
            commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            
            commandEncoder.endEncoding()
            
            // Run render pass for presentation
            guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            renderEncoder.label = "PassThrough"
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentTexture(outTexture, index: 0)
            renderEncoder.setFragmentSamplerState(sampler, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = context.coordinator.device
        mtkView.delegate = context.coordinator
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.brightness = brightness
    }
    
    var brightness: Float
}

// Helper to load texture
func loadTexture(named name: String, device: MTLDevice) -> MTLTexture? {
    guard let image = NSImage(named: name),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }
    let loader = MTKTextureLoader(device: device)
    return try? loader.newTexture(cgImage: cgImage, options: [.SRGB: false])
}

#Preview {
    MetalView(brightness: 0.0)
}
