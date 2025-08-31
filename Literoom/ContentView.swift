//
//  ContentView.swift
//  Literoom
//
//  Created by Brennan Andruss on 8/30/25.
//

import SwiftUI

struct ContentView: View {
    @State private var brightness: Float = 0.0
    
    var body: some View {
        VStack {
            MetalView(brightness: brightness)
            Slider(value: Binding(
                get: { Double(brightness) },
                set: { brightness = Float($0) }
            ), in: -0.5...0.5)
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
