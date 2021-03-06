//
//  Model.swift
//  MeshViewer
//
//  Created by Robby on 3/6/21.
//

import Foundation
import MetalKit

open class Model: NSObject {
  public let device: MTLDevice! // must set on init()
  open var vertexDescriptor: MTLVertexDescriptor! // must set after building vertices
  open var boundingBox: MDLAxisAlignedBoundingBox {
    get { MDLAxisAlignedBoundingBox(maxBounds: [0, 0, 0], minBounds: [0, 0, 0]) }
  }
  open func draw(commandEncoder: MTLRenderCommandEncoder) { }
  init(device: MTLDevice) {
    self.device = device
    super.init()
  }
}
