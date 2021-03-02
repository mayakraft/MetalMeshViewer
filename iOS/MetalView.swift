//
//  MetalView.swift
//  MetalMeshView (iOS)
//
//  Created by Robby on 3/2/21.
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: UIViewRepresentableContext<MetalView>) -> MTKView {
    let mtkView = MTKView()
    mtkView.delegate = context.coordinator
    mtkView.preferredFramesPerSecond = 60
    mtkView.enableSetNeedsDisplay = true
    if let metalDevice = MTLCreateSystemDefaultDevice() {
      mtkView.device = metalDevice
    }
    mtkView.framebufferOnly = false
    mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    mtkView.drawableSize = mtkView.frame.size
    mtkView.enableSetNeedsDisplay = true
    mtkView.isPaused = false
    return mtkView
  }

  func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<MetalView>) {
  }
}
