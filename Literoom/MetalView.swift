//
//  MetalView.swift
//  Literoom
//
//  Created by Brennan Andruss on 8/30/25.
//

import SwiftUI
import Metal
import MetalKit

#if os(macOS)
import AppKit
typealias ViewRepresentable = NSViewRepresentable
#else
import UIKit
typealias ViewRepresentable = UIViewRepresentable
#endif

struct MetalView: ViewRepresentable {
    let brightness: Float
    let contrast: Float
    let saturation: Float
    let blur: Float
    let image: CGImage?
    
    func makeCoordinator() -> Renderer { Renderer(self) }
    
#if os(iOS)
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = context.coordinator.device
        mtkView.delegate = context.coordinator
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.setBrightness(brightness: brightness)
        context.coordinator.setContrast(contrast: contrast)
        context.coordinator.setSaturation(saturation: saturation)
        context.coordinator.setBlur(radius: blur)
        
        guard let cgImage = image else {
            return
        }
        
        context.coordinator.setTexture(cgImage: cgImage)
    }
#elseif os(macOS)
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = context.coordinator.device
        mtkView.delegate = context.coordinator
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.setBrightness(brightness: brightness)
        context.coordinator.setContrast(contrast: contrast)
        context.coordinator.setSaturation(saturation: saturation)
        context.coordinator.setBlur(radius: blur)
        
        guard let cgImage = image else {
            return
        }
        
        context.coordinator.setTexture(cgImage: cgImage)
    }
#endif
}

#Preview {
    MetalView(
        brightness: 0.0,
        contrast: 0.0,
        saturation: 1.0,
        blur: 1.0,
        image: loadImage(named: "Image1")
    )
}
