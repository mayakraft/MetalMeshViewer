//
//  ModelRaw.swift
//  MeshViewer
//
//  Created by Robby on 3/5/21.
//

import Foundation
import MetalKit

// make a mesh by providing the raw data:
// vertices and faces, as an array of floats and ints
// this is hard-coded to use mesh triangles (not tri-strips)
// but it can be easily extended to lines/strips/...
class ModelRaw: Model {
  var vertexBuffer: MTLBuffer!
  var triangleBuffer: MTLBuffer!
  var trianglesCount: Int = 0

  // get the bounding box by iterating over all the vertices
  // this assumes that there are no normals/colors mixed in
  override var boundingBox: MDLAxisAlignedBoundingBox {
    get {
      let vertices = vertexBuffer.contents().assumingMemoryBound(to: Float32.self)
      let verticesLength = vertexBuffer.length / MemoryLayout<Float32>.size
      var mins = vector_float3(repeating: Float.infinity)
      var maxs = vector_float3(repeating: -Float.infinity)
      for i in 0..<(verticesLength / 3) {
        // three dimensions, hardcoded
        for d in 0..<3 {
          if vertices[i*3+d] < mins[d] { mins[d] = vertices[i*3+d] }
          if vertices[i*3+d] > maxs[d] { maxs[d] = vertices[i*3+d] }
        }
      }
      return MDLAxisAlignedBoundingBox(maxBounds: maxs, minBounds: mins)
    }
  }

  init(device: MTLDevice, vertices: [Float32], triangles: [UInt16]) {
    super.init(device: device)
    loadArrays(vertices: vertices, triangles: triangles)
  }

  internal func loadArrays(vertices: [Float32], triangles: [UInt16]) {
    let verticesPointer = UnsafeMutablePointer<Float32>.allocate(capacity: vertices.count)
    let trianglesPointer = UnsafeMutablePointer<UInt16>.allocate(capacity: triangles.count)
    vertices.enumerated().forEach { verticesPointer[$0.offset] = $0.element }
    triangles.enumerated().forEach { trianglesPointer[$0.offset] = $0.element }
    vertexBuffer = device.makeBuffer(bytes: verticesPointer,
                                     length: MemoryLayout<Float32>.size * vertices.count,
                                     options: [])
    triangleBuffer = device.makeBuffer(bytes: trianglesPointer,
                                       length: MemoryLayout<UInt16>.size * triangles.count,
                                       options: [])
    trianglesCount = triangles.count / 3
    vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.layouts[0].stride = MemoryLayout<Float32>.size * 3
  }

  override func draw(commandEncoder: MTLRenderCommandEncoder) {
    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    commandEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle,
                                         indexCount: trianglesCount * 3,
                                         indexType: MTLIndexType.uint16,
                                         indexBuffer: triangleBuffer,
                                         indexBufferOffset: 0)
  }
}
