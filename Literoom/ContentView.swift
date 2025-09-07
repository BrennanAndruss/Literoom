//
//  ContentView.swift
//  Literoom
//
//  Created by Brennan Andruss on 9/1/25.
//

import SwiftUI

struct ContentView: View {
    @State private var brightness: Float = 0.0
    @State private var contrast: Float = 0.0
    @State private var saturation: Float = 1.0
    @State private var blur: Float = 0.0
    @State private var selectedImage: CGImage?
    
    var body: some View {
        VStack {
            MetalView(
                brightness: brightness,
                contrast: contrast,
                saturation: saturation,
                blur: blur,
                image: selectedImage
            )
            Slider(value: $brightness, in: -0.5...0.5)
                .padding()
            Slider(value: $contrast, in: -0.5...0.5)
                .padding()
            Slider(value: $saturation, in: -1.0...1.0)
                .padding()
            Slider(value: $blur, in: 0.0...25.0)
                .padding()
        }
    }
}

func loadImage(named name: String) -> CGImage? {
#if os(iOS)
    guard let image = UIImage(named: name),
          let cgImage = image.cgImage else {
        return nil
    }
#elseif os(macOS)
    guard let image = NSImage(named: name),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }
#endif
    
    return cgImage
}

#Preview {
    ContentView()
}
