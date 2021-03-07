//
//  ModelRaw.swift
//  MeshViewer
//
//  Created by Robby on 3/5/21.
//

import Foundation
import MetalKit

// make a mesh by using Metal's MeshIO, but loading the arrays
// from user supplied data
class ModelMesh: ModelRaw {
  var mesh: MTKMesh!
  
  var verticesStride: Int = 8
  var verticesCount: Int = 0
//  var trianglesCount: Int = 0
  
  override init(device: MTLDevice, vertices: [Float32], triangles: [UInt16]) {
    super.init(device: device, vertices: vertices, triangles: triangles)
    makeBuffers(vertices: vertices, triangles: triangles)
    makeVertexDescriptor()
    makeMesh()
  }
  
  // this allocates memory. will need to be freed
  func makeBuffers(vertices: [Float32], triangles: [UInt16]) {
    verticesCount = vertices.count / 3
    trianglesCount = triangles.count / 3
    let verticesPointer = UnsafeMutablePointer<Float32>.allocate(capacity: verticesCount * verticesStride)
    let trianglesPointer = UnsafeMutablePointer<UInt16>.allocate(capacity: triangles.count)
    // fill vertices and interleave normals and texture
    for i in 0..<verticesCount {
      verticesPointer[i * verticesStride + 0] = vertices[i * 3 + 0]
      verticesPointer[i * verticesStride + 1] = vertices[i * 3 + 1]
      verticesPointer[i * verticesStride + 2] = vertices[i * 3 + 2]
      verticesPointer[i * verticesStride + 3] = 0.0 // normal
      verticesPointer[i * verticesStride + 4] = 0.0 // normal
      verticesPointer[i * verticesStride + 5] = 0.0 // normal
      verticesPointer[i * verticesStride + 6] = 0.0 // texture
      verticesPointer[i * verticesStride + 7] = 0.0 // texture
    }
    triangles.enumerated().forEach { trianglesPointer[$0.offset] = $0.element }
    vertexBuffer = device.makeBuffer(bytes: verticesPointer,
                                     length: MemoryLayout<Float32>.size * verticesCount * verticesStride,
                                     options: [])
    triangleBuffer = device.makeBuffer(bytes: trianglesPointer,
                                       length: MemoryLayout<UInt16>.size * trianglesCount * 3,
                                       options: [])
  }
  
  func makeVertexDescriptor() {
    vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[1].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[1].bufferIndex = 0
    vertexDescriptor.attributes[1].offset = MemoryLayout<Float32>.size * 3
    vertexDescriptor.attributes[2].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[2].bufferIndex = 0
    vertexDescriptor.attributes[2].offset = MemoryLayout<Float32>.size * 6
    vertexDescriptor.layouts[0].stride = MemoryLayout<Float32>.size * 8
  }

  func makeMesh() {
    let vertexData = Data(bytesNoCopy: vertexBuffer.contents().assumingMemoryBound(to: Float32.self),
                          count: MemoryLayout<Float32>.size * verticesStride * verticesCount,
                          deallocator: .none)
    let triangleData = Data(bytesNoCopy: triangleBuffer.contents().assumingMemoryBound(to: UInt16.self),
                            count: MemoryLayout<UInt16>.size * 3 * trianglesCount,
                            deallocator: .none)
    let allocator = MTKMeshBufferAllocator(device: device)
    let mdlVertexBuffer = allocator.newBuffer(with: vertexData, type: MDLMeshBufferType.vertex)
    let mdlTriangleBuffer = allocator.newBuffer(with: triangleData, type: .index)
    let submesh = MDLSubmesh(indexBuffer: mdlTriangleBuffer,
                             indexCount: 3 * trianglesCount,
                             indexType: .uInt16,
                             geometryType: .triangles,
                             material: nil)
    let mdlVertexDescriptor = MDLVertexDescriptor()
    let attributePosition = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                               format: .float3,
                                               offset: 0,
                                               bufferIndex: 0)
    let attributeNormal = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                             format: .float3,
                                             offset: MemoryLayout<Float32>.size * 3,
                                             bufferIndex: 0)
    let attributeTexture = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                              format: .float2,
                                              offset: MemoryLayout<Float32>.size * 6,
                                              bufferIndex: 0)
    let descriptorLayout = MDLVertexBufferLayout(stride: MemoryLayout<Float32>.size * 8)
    mdlVertexDescriptor.attributes = [attributePosition, attributeNormal, attributeTexture]
    mdlVertexDescriptor.layouts = [descriptorLayout]
    let mdlMesh = MDLMesh(vertexBuffer: mdlVertexBuffer,
                       vertexCount: verticesCount,
                       descriptor: mdlVertexDescriptor,
                       submeshes: [submesh])
    mdlMesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0)
    do {
      mesh = try MTKMesh(mesh: mdlMesh, device: device)
    } catch let error {
      print(error)
    }
  }

  override func draw(commandEncoder: MTLRenderCommandEncoder) {
    commandEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
    for submesh in mesh.submeshes {
      commandEncoder.drawIndexedPrimitives(type: .triangle,
                                           indexCount: submesh.indexCount,
                                           indexType: submesh.indexType,
                                           indexBuffer: submesh.indexBuffer.buffer,
                                           indexBufferOffset: 0)
    }
  }

//  func printVertexBuffer(vertexBuffer: MDLMeshBuffer) {
//    let map = vertexBuffer.map()
//    let pointer = map.bytes.assumingMemoryBound(to: Float32.self)
//    let bufferLength = vertexBuffer.length / MemoryLayout<Float32>.size
//    print("BUFFER CONTENTS \(vertexBuffer.length)bytes \(bufferLength)floats")
//    for i in 0..<bufferLength {
//      print("\(i): \(pointer[i])")
//    }
//  }
//
//  func analyzeMesh(mesh: MTKMesh) {
//    let verts = mesh.vertexBuffers[0]
//    print("Analysis submesh \(mesh.submeshes.count) verts \(verts.name) \(verts.length) \(verts.offset)")
//    let vertices = verts.buffer.contents().bindMemory(to: Float.self, capacity: mesh.vertexCount * 3)
//    print("vertices 0 1 2 \(vertices[0]) \(vertices[1]) \(vertices[2])")
//    print("vertices 3 4 5 \(vertices[3]) \(vertices[4]) \(vertices[5])")
//    print("vertices 6 7 8 \(vertices[6]) \(vertices[7]) \(vertices[8])")
//    print("vertices 9 10 11 \(vertices[9]) \(vertices[10]) \(vertices[11])")
//    print("vertices 12 13 14 \(vertices[12]) \(vertices[13]) \(vertices[14])")
//  }

}
