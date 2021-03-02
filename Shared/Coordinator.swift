//
//  Coordinator.swift
//  MetalMeshView
//
//  Created by Robby on 3/2/21.
//

import Foundation
import MetalKit

class Coordinator : NSObject, MTKViewDelegate {
  var parent: MetalView
  var metalDevice: MTLDevice!
  var metalCommandQueue: MTLCommandQueue!
  
  init(_ parent: MetalView) {
    self.parent = parent
    if let metalDevice = MTLCreateSystemDefaultDevice() {
      self.metalDevice = metalDevice
    }
    self.metalCommandQueue = metalDevice.makeCommandQueue()!
    super.init()
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable else { return }
    let commandBuffer = metalCommandQueue.makeCommandBuffer()
    let rpd = view.currentRenderPassDescriptor
    rpd?.colorAttachments[0].clearColor = MTLClearColorMake(0, 1, 0, 1)
    rpd?.colorAttachments[0].loadAction = .clear
    rpd?.colorAttachments[0].storeAction = .store
    let re = commandBuffer?.makeRenderCommandEncoder(descriptor: rpd!)
    re?.endEncoding()
    commandBuffer?.present(drawable)
    commandBuffer?.commit()
  }
}
