//
//  Renderer.swift
//  Literoom
//
//  Created by Brennan Andruss on 8/31/25.
//

import Metal
import MetalKit
import simd

struct Vertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
}

class Renderer: NSObject, MTKViewDelegate {
    var parent: MetalView
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
    
    var texture: MTLTexture?
    var textureAspect: Float = 1.0
    var viewAspect: Float = 1.0
    var scale: SIMD2<Float> = [1.0, 1.0]
    
    var vertexBuffer: MTLBuffer!
    var sampler: MTLSamplerState!
    
    var brightnessRenderer: BrightnessRenderer?
    var contrastRenderer: ContrastRenderer?
    
    init(_ parent: MetalView) {
        self.parent = parent
        super.init()
        
        device = MTLCreateSystemDefaultDevice()!
        
        configureMetal()
        configureResources()
    }
    
    private func configureMetal() {
        commandQueue = device.makeCommandQueue()!
        let library = device.makeDefaultLibrary()!
        
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
    
    private func configureResources() {
        // Create textured quad to cover the MetalView
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
        
        // Load filter renderers
        brightnessRenderer = BrightnessRenderer(device: device)
        contrastRenderer = ContrastRenderer(device: device)
        
        // Load texture with sample image
        guard let cgImage = loadImage(named: "Image1") else {
            return
        }
        setTexture(cgImage: cgImage)
    }
    
    func draw(in view: MTKView) {
        // Only draw if input texture and output drawable are present
        guard let inTexture = texture,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create Metal command buffer")
            return
        }
        
        // Create intermediate output textures for compute passes
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: inTexture.width,
            height: inTexture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texA = device.makeTexture(descriptor: descriptor),
              let texB = device.makeTexture(descriptor: descriptor),
              let texC = device.makeTexture(descriptor: descriptor) else {
            return
        }
        
        // Copy image into texA
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.copy(from: inTexture,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: inTexture.width, height: inTexture.height, depth: 1),
                         to: texA,
                         destinationSlice: 0,
                         destinationLevel: 0,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blitEncoder.endEncoding()
//        
//        // Dispatch compute passes
//        brightnessRenderer!.encode(commandBuffer: commandBuffer, inTexture: texA, outTexture: texB)
//        contrastRenderer!.encode(commandBuffer: commandBuffer, inTexture: texB, outTexture: texA)
//        let outTexture = texA
        
        brightnessRenderer!.encode(commandBuffer: commandBuffer, inTexture: texA, outTexture: texB)
        contrastRenderer!.encode(commandBuffer: commandBuffer, inTexture: texB, outTexture: texC)
        
        // Run passthrough render pass for presentation
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.label = "PassThrough"
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&scale, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        renderEncoder.setFragmentTexture(texC, index: 0)
        renderEncoder.setFragmentSamplerState(sampler, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewAspect = Float(size.width) / Float(size.height)
        updateScale()
    }
    
    func updateScale() {
        // Scale the quad fit the image inside the drawable, maintaining aspect ratio
        scale = [1.0, 1.0]
        if textureAspect > viewAspect {
            // Image wider than view -> scale Y
            scale.y = viewAspect / textureAspect
        } else {
            // Image taller than view -> scale X
            scale.x = textureAspect / viewAspect
        }
    }
    
    func setTexture(cgImage: CGImage) {
        let loader = MTKTextureLoader(device: device)
        do {
            texture = try loader.newTexture(cgImage: cgImage, options: [.SRGB: false])
            textureAspect = Float(texture!.width) / Float(texture!.height)
            updateScale()
        } catch {
            print("Failed to load Metal texture")
        }
    }
    
    func setBrightness(brightness: Float) {
        brightnessRenderer?.update(brightness: brightness)
    }
    
    func setContrast(contrast: Float) {
        contrastRenderer?.update(contrast: contrast)
    }
}

// Helper to load textures by image name
func loadTexture(named name: String, device: MTLDevice) -> MTLTexture? {
    guard let cgImage = loadImage(named: name) else { return nil }
    
    let loader = MTKTextureLoader(device: device)
    return try? loader.newTexture(cgImage: cgImage, options: [.SRGB: false])
}
