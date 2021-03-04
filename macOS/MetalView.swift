//
//  MetalView.swift
//  MetalMeshView (macOS)
//
//  Created by Robby on 3/2/21.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {

  func makeCoordinator() -> Renderer {
    Renderer(self)
  }

  func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
    let mtkView = MTKMouseView()
    mtkView.delegate = context.coordinator
    context.coordinator.mtkView = mtkView
    // transparent on MacOS only
    mtkView.layer?.backgroundColor = NSColor.clear.cgColor
    mtkView.layer?.isOpaque = false
    return mtkView
  }

  func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
  }
}
