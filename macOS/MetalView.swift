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
    mtkView.delegate = context.coordinator
    return mtkView
  }

  func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
  }
}
