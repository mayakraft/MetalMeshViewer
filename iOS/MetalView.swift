//
//  MetalView.swift
//  MetalMeshView (iOS)
//
//  Created by Robby on 3/2/21.
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {

  func makeCoordinator() -> Renderer {
    Renderer(self)
  }

  func makeUIView(context: UIViewRepresentableContext<MetalView>) -> MTKView {
    let mtkView = MTKTouchView()
    mtkView.delegate = context.coordinator
    context.coordinator.mtkView = mtkView
    return mtkView
  }

  func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<MetalView>) {
  }
}
