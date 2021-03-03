//
//  MetalView.swift
//  MetalMeshView (iOS)
//
//  Created by Robby on 3/2/21.
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {

  let mtkView = MTKView()

  func makeCoordinator() -> Renderer {
    let renderer = Renderer(self)
    renderer.mtkView = self.mtkView
    return renderer
  }

  func makeUIView(context: UIViewRepresentableContext<MetalView>) -> MTKView {
    mtkView.delegate = context.coordinator
    return mtkView
  }

  func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<MetalView>) {
  }
}
