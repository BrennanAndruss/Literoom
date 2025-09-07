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
    
    var inTexture: MTLTexture?
    var outTexture: MTLTexture!
    var scratchA: MTLTexture!
    var scratchB: MTLTexture!
    var dirtyFlag: Bool = true
    
    var textureAspect: Float = 1.0
    var viewAspect: Float = 1.0
    var scale: SIMD2<Float> = [1.0, 1.0]
    
    var vertexBuffer: MTLBuffer!
    var sampler: MTLSamplerState!
    
    var filters: [FilterRenderer] = []
    var brightnessRenderer: BrightnessRenderer!
    var contrastRenderer: ContrastRenderer!
    var saturationRenderer: SaturationRenderer!
    var blurRenderer: BlurRenderer!
    
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
        saturationRenderer = SaturationRenderer(device: device)
        blurRenderer = BlurRenderer(device: device)
        
        filters = [brightnessRenderer, contrastRenderer, saturationRenderer, blurRenderer]
        
        // Load texture with sample image
        guard let cgImage = loadImage(named: "Image1") else {
            return
        }
        setTexture(cgImage: cgImage)
        
        // Create output texture and intermediate texture for ping-ponging
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: inTexture!.width,
            height: inTexture!.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        outTexture = device.makeTexture(descriptor: descriptor)!
        scratchA = device.makeTexture(descriptor: descriptor)!
        scratchB = device.makeTexture(descriptor: descriptor)!
    }
    
    func draw(in view: MTKView) {
        // Only draw if input texture and output drawable are present
        guard let inTexture = inTexture,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create Metal command buffer")
            return
        }
        
        // Apply filters when parameters are modified
        if dirtyFlag {
            applyFilters(commandBuffer: commandBuffer, inTexture: inTexture, outTexture: outTexture)
            dirtyFlag = false
        }
        
        // Run passthrough render pass for presentation
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.label = "PassThrough"
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&scale, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        renderEncoder.setFragmentTexture(outTexture, index: 0)
        renderEncoder.setFragmentSamplerState(sampler, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func applyFilters(commandBuffer: MTLCommandBuffer, inTexture: MTLTexture, outTexture: MTLTexture) {
        var src = inTexture
        var dest = scratchA!
        
        for (i, filter) in filters.enumerated() {
            // Write into the outTexture on the last filter
            if (i == filters.count - 1) {
                dest = outTexture
            } else {
                // Alternate between scratch textures for intermediate outputs
                dest = (i % 2 == 0) ? scratchA! : scratchB!
            }
            
            filter.encode(commandBuffer: commandBuffer, inTexture: src, outTexture: dest)
            src = dest
        }
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
            inTexture = try loader.newTexture(cgImage: cgImage, options: [.SRGB: false])
            textureAspect = Float(inTexture!.width) / Float(inTexture!.height)
            updateScale()
        } catch {
            print("Failed to load Metal texture")
        }
    }
    
    func setBrightness(brightness: Float) {
        brightnessRenderer?.update(value: brightness)
        dirtyFlag = true
    }
    
    func setContrast(contrast: Float) {
        contrastRenderer?.update(value: contrast)
        dirtyFlag = true
    }
    
    func setSaturation(saturation: Float) {
        saturationRenderer?.update(value: saturation)
        dirtyFlag = true
    }
    
    func setBlur(radius: Float) {
        blurRenderer?.update(value: radius)
        dirtyFlag = true
    }
}

// Helper to load textures by image name
func loadTexture(named name: String, device: MTLDevice) -> MTLTexture? {
    guard let cgImage = loadImage(named: name) else { return nil }
    
    let loader = MTKTextureLoader(device: device)
    return try? loader.newTexture(cgImage: cgImage, options: [.SRGB: false])
}
