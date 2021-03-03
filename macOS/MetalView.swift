//
//  MetalView.swift
//  MetalMeshView (macOS)
//
//  Created by Robby on 3/2/21.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {

  let mtkView = MTKView()

  func makeCoordinator() -> Renderer {
    let renderer = Renderer(self)
    renderer.mtkView = self.mtkView
    return renderer
  }

  func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
//    let mtkView = MTKView()
    mtkView.delegate = context.coordinator
    mtkView.preferredFramesPerSecond = 60
    mtkView.enableSetNeedsDisplay = true
    // throw error, your device is old or something
    guard let metalDevice = MTLCreateSystemDefaultDevice() else { return mtkView }
    mtkView.device = metalDevice
    mtkView.framebufferOnly = false
    mtkView.clearColor = MTLClearColor(red: 1, green: 0, blue: 0.5, alpha: 0)
    mtkView.drawableSize = mtkView.frame.size
    mtkView.enableSetNeedsDisplay = true
    mtkView.isPaused = false
    // might need these
//    mtkView.colorPixelFormat = .bgra8Unorm_srgb
//    mtkView.depthStencilPixelFormat = .depth32Float
    return mtkView
  }

  func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
  }
}
