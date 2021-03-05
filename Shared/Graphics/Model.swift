//
//  Mesh.swift
//  MeshViewer
//
//  Created by Robby on 3/5/21.
//

import Foundation
import MetalKit

class Model: NSObject {
  let device: MTLDevice!
  let mtkView: MTKView!
  var asset: MDLAsset!
  var mdlMeshes: [MDLMesh] = []
  var mtkMeshes: [MTKMesh] = []
  var vertexDescriptor: MTLVertexDescriptor!
  
  init(device: MTLDevice, view: MTKView) {
    self.device = device
    self.mtkView = view
    super.init()
  }

  func loadResources(url: URL) throws {
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
    asset = MDLAsset(url: url,
                     vertexDescriptor: vertexDescriptor,
                     bufferAllocator: bufferAllocator)
    do {
      (mdlMeshes, mtkMeshes) = try MTKMesh.newMeshes(asset: asset, device: device)
    } catch let error {
      throw error
    }

//    analyzeMesh(mesh: mtkMeshes[0])
//    print("count before \(mtkMeshes[0].vertexCount) \(mdlMeshes[0].vertexCount)")
//    mdlMeshes[0].addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.0)
//    print("count after \(mtkMeshes[0].vertexCount) \(mdlMeshes[0].vertexCount)")
  }

  func draw(commandEncoder: MTLRenderCommandEncoder) {
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
  
  func analyzeMesh(mesh: MTKMesh) {
    let verts = mesh.vertexBuffers[0]
    print("Analysis submesh \(mesh.submeshes.count) verts \(verts.name) \(verts.length) \(verts.offset)")
    let vertices = verts.buffer.contents().bindMemory(to: Float.self, capacity: mesh.vertexCount * 3)
    print("vertices 0 1 2 \(vertices[0]) \(vertices[1]) \(vertices[2])")
    print("vertices 3 4 5 \(vertices[3]) \(vertices[4]) \(vertices[5])")
    print("vertices 6 7 8 \(vertices[6]) \(vertices[7]) \(vertices[8])")
    print("vertices 9 10 11 \(vertices[9]) \(vertices[10]) \(vertices[11])")
    print("vertices 12 13 14 \(vertices[12]) \(vertices[13]) \(vertices[14])")
  }

}
