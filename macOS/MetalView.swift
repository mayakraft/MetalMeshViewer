//
//  MetalView.swift
//  MetalMeshView (macOS)
//
//  Created by Robby on 3/2/21.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {

  let mtkView = MTKTouchView()

  func makeCoordinator() -> Renderer {
    let renderer = Renderer(self)
    renderer.mtkView = self.mtkView
    return renderer
  }

  func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
    mtkView.delegate = context.coordinator
    // transparent on MacOS only
    mtkView.layer?.backgroundColor = NSColor.clear.cgColor
    mtkView.layer?.isOpaque = false
    return mtkView
  }

  func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
  }
}
