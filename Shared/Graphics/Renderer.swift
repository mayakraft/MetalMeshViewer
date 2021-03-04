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

struct Uniforms {
  var modelViewMatrix: float4x4
  var projectionMatrix: float4x4
}

class Renderer: NSObject, MTKViewDelegate {
  let parent: MetalView
  let device: MTLDevice!
  let commandQueue: MTLCommandQueue
  var vertexDescriptor: MTLVertexDescriptor!
  var renderPipeline: MTLRenderPipelineState!
  var depthStencilState: MTLDepthStencilState!
  var mdlMeshes: [MDLMesh] = []
  var mtkMeshes: [MTKMesh] = []
  var camera: Camera!

  // must set mtkView
  var mtkView: MTKGestureView? {
    didSet {
      if let mtkView = self.mtkView {
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.device = self.device
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.drawableSize = mtkView.frame.size
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.depthStencilPixelFormat = .depth32Float
        // camera and wire touch delegate to camera
        camera = Camera(with: mtkView)
        mtkView.touchDelegate = camera
        // init app. load model
        loadResources()
        buildPipeline(view: mtkView)

//        if let url = Bundle.main.url(forResource: "bunny", withExtension: "obj") {
//          loadModel(url: url)
//        } else {
//          print("could not load file")
//        }
      }
    }
  }

/*
  func loadModel(url: URL) {}
*/

  init(_ parent: MetalView) {
    self.parent = parent
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!

    let depthDesecriptor = MTLDepthStencilDescriptor()
    depthDesecriptor.depthCompareFunction = .lessEqual
    depthDesecriptor.isDepthWriteEnabled = true
    self.depthStencilState = device.makeDepthStencilState(descriptor: depthDesecriptor)

    super.init()
  }

  func loadResources() {
    let modelURL = Bundle.main.url(forResource: "bunny", withExtension: "obj")!
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
    let asset = MDLAsset(url: modelURL,
                         vertexDescriptor: vertexDescriptor,
                         bufferAllocator: bufferAllocator)
    do {
      (mdlMeshes, mtkMeshes) = try MTKMesh.newMeshes(asset: asset, device: device)
    } catch {
      fatalError("Could not extract meshes from Model I/O asset")
    }
//    analyzeMesh(mesh: mtkMeshes[0])

//    print("count before \(mtkMeshes[0].vertexCount) \(mdlMeshes[0].vertexCount)")
//    mdlMeshes[0].addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.0)
//    print("count after \(mtkMeshes[0].vertexCount) \(mdlMeshes[0].vertexCount)")

    // very important, set the model data for the camera
    camera.modelBounds = asset.boundingBox
  }

  func buildPipeline(view: MTKView) {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Could not load default library from main bundle")
    }
    let vertexFunction = library.makeFunction(name: "vertex_main")
    let fragmentFunction = library.makeFunction(name: "fragment_main")
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    pipelineDescriptor.vertexDescriptor = self.vertexDescriptor
    do {
      renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch let error {
      fatalError("Could not create render pipeline state object \(error)")
    }
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
  }

  func drawMesh(commandEncoder: MTLRenderCommandEncoder) {
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

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let renderPassDescriptor = view.currentRenderPassDescriptor,
          let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
      else { return }

    commandEncoder.setRenderPipelineState(renderPipeline)
    commandEncoder.setDepthStencilState(depthStencilState)
    var uniforms = Uniforms(modelViewMatrix: camera.modelView,
                            projectionMatrix: camera.projection)
    commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
    drawMesh(commandEncoder: commandEncoder)
    commandEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  
//  func drawBlankScreen() {
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
//  }

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
