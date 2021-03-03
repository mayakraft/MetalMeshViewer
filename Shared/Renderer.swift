//
//  Renderer.swift
//  MeshViewer
//
//  Created by Robby on 3/2/21.
//

import Foundation
import MetalKit
import ModelIO
import simd

extension float4x4 {
  init(scaleBy s: Float) {
    self.init(SIMD4<Float>(s, 0, 0, 0),
              SIMD4<Float>(0, s, 0, 0),
              SIMD4<Float>(0, 0, s, 0),
              SIMD4<Float>(0, 0, 0, 1))
  }
  init(rotationAbout axis: SIMD3<Float>, by angleRadians: Float) {
      let x = axis.x, y = axis.y, z = axis.z
      let c = cosf(angleRadians)
      let s = sinf(angleRadians)
      let t = 1 - c
      self.init(SIMD4<Float>( t * x * x + c,     t * x * y + z * s, t * x * z - y * s, 0),
                SIMD4<Float>( t * x * y - z * s, t * y * y + c,     t * y * z + x * s, 0),
                SIMD4<Float>( t * x * z + y * s, t * y * z - x * s,     t * z * z + c, 0),
                SIMD4<Float>(                 0,                 0,                 0, 1))
  }

  init(translationBy t: SIMD3<Float>) {
      self.init(SIMD4<Float>(   1,    0,    0, 0),
                SIMD4<Float>(   0,    1,    0, 0),
                SIMD4<Float>(   0,    0,    1, 0),
                SIMD4<Float>(t[0], t[1], t[2], 1))
  }

  init(perspectiveProjectionFov fovRadians: Float, aspectRatio aspect: Float, nearZ: Float, farZ: Float) {
      let yScale = 1 / tan(fovRadians * 0.5)
      let xScale = yScale / aspect
      let zRange = farZ - nearZ
      let zScale = -(farZ + nearZ) / zRange
      let wzScale = -2 * farZ * nearZ / zRange

      let xx = xScale
      let yy = yScale
      let zz = zScale
      let zw = Float(-1)
      let wz = wzScale

      self.init(SIMD4<Float>(xx,  0,  0,  0),
                SIMD4<Float>( 0, yy,  0,  0),
                SIMD4<Float>( 0,  0, zz, zw),
                SIMD4<Float>( 0,  0, wz,  0))
  }
}

struct Uniforms {
  var modelViewMatrix: float4x4
  var projectionMatrix: float4x4
}

class Renderer: NSObject, MTKViewDelegate {
  var parent: MetalView

  // must set mtkView
  var mtkView: MTKView? {
    didSet {
      loadResources()
      buildPipeline()
    }
  }

  let device: MTLDevice!
  let commandQueue: MTLCommandQueue
  var vertexDescriptor: MTLVertexDescriptor!
  var renderPipeline: MTLRenderPipelineState!
  var vertexBuffer: MTLBuffer!
  var meshes: [MTKMesh] = []
  var time: Float = 0

  init(_ parent: MetalView) {
    self.parent = parent
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!
    super.init()
  }

  func loadResources() {
    let modelURL = Bundle.main.url(forResource: "bunny", withExtension: "obj")!
    let vertexDescriptor = MDLVertexDescriptor()
    vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
    vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size * 3, bufferIndex: 0)
    vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size * 6, bufferIndex: 0)
    vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)

    self.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
    let bufferAllocator = MTKMeshBufferAllocator(device: device)
    let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
    do {
      (_, meshes) = try MTKMesh.newMeshes(asset: asset, device: device)
    } catch {
      fatalError("Could not extract meshes from Model I/O asset")
    }

    // HACK
    self.vertexBuffer = meshes[0].vertexBuffers[0].buffer
  }
  
  func buildPipeline() {
    guard let mtkView = self.mtkView else { return }
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Could not load default library from main bundle")
    }
    let vertexFunction = library.makeFunction(name: "vertex_main")
    let fragmentFunction = library.makeFunction(name: "fragment_main")
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    pipelineDescriptor.vertexDescriptor = self.vertexDescriptor
    do {
      renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch let error {
      fatalError("Could not create render pipeline state object \(error)")
    }
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
  }

  func draw(in view: MTKView) {
//    guard let drawable = view.currentDrawable else { return }
//    let rpd = view.currentRenderPassDescriptor
//    rpd?.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0.5, 1)
//    rpd?.colorAttachments[0].loadAction = .clear
//    rpd?.colorAttachments[0].storeAction = .store
//    let commandBuffer = commandQueue.makeCommandBuffer()
//    let re = commandBuffer?.makeRenderCommandEncoder(descriptor: rpd!)
//    re?.endEncoding()
//    commandBuffer?.present(drawable)
//    commandBuffer?.commit()

    guard let mtkView = self.mtkView else { return }
    let commandBuffer = commandQueue.makeCommandBuffer()!
    if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
      let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
      
      time += 1 / Float(mtkView.preferredFramesPerSecond)
      let angle = -time
      let modelMatrix = float4x4(rotationAbout: SIMD3<Float>(0, 1, 0), by: angle)
      let viewMatrix = float4x4(translationBy: SIMD3<Float>(0, 0, -1))
      let modelViewMatrix = viewMatrix * modelMatrix
      let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
      let projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
      var uniforms = Uniforms(modelViewMatrix: modelViewMatrix, projectionMatrix: projectionMatrix)
      commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)

      commandEncoder.setRenderPipelineState(renderPipeline)
      commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

      for mesh in meshes {
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
      commandEncoder.endEncoding()
      commandBuffer.present(drawable)
      commandBuffer.commit()
    }

  }
}
