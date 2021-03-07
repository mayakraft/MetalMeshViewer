//
//  Mesh.swift
//  MeshViewer
//
//  Created by Robby on 3/5/21.
//

import Foundation
import MetalKit

// make a mesh by loading it from a file, using Metal's MeshIO
class ModelFile: Model {
  var mdlMeshes: [MDLMesh] = []
  var mtkMeshes: [MTKMesh] = []

  override var boundingBox: MDLAxisAlignedBoundingBox {
    get {
      if let mesh = mdlMeshes.first {
        return mesh.boundingBox
      } else {
        return MDLAxisAlignedBoundingBox(maxBounds: [0, 0, 0], minBounds: [0, 0, 0])
      }
    }
  }

  init(device: MTLDevice, file: URL) {
    super.init(device: device)
    MTKModelIOVertexDescriptorFromMetal(MTLVertexDescriptor())
    let vertexDescriptor = MDLVertexDescriptor()
    vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
    vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                        format: .float3,
                                                        offset: 0,
                                                        bufferIndex: 0)
    vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                        format: .float3,
                                                        offset: MemoryLayout<Float>.size * 3,
                                                        bufferIndex: 0)
    vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                        format: .float2,
                                                        offset: MemoryLayout<Float>.size * 6,
                                                        bufferIndex: 0)
    self.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
    let bufferAllocator = MTKMeshBufferAllocator(device: device)
    let asset = MDLAsset(url: file,
                         vertexDescriptor: vertexDescriptor,
                         bufferAllocator: bufferAllocator)
    do {
      (self.mdlMeshes, self.mtkMeshes) = try MTKMesh.newMeshes(asset: asset, device: device)
    } catch let error{
      fatalError(error.localizedDescription)
    }
  }

  override func draw(commandEncoder: MTLRenderCommandEncoder) {
    for mesh in mtkMeshes {
      for vertexBuffer in mesh.vertexBuffers {
        commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
        for submesh in mesh.submeshes {
          let indexBuffer = submesh.indexBuffer
          commandEncoder.drawIndexedPrimitives(
            type: submesh.primitiveType,
            indexCount: submesh.indexCount,
            indexType: submesh.indexType,
            indexBuffer: indexBuffer.buffer,
            indexBufferOffset: indexBuffer.offset)
        }
      }
    }
  }
}
