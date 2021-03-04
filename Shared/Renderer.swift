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

class Renderer: NSObject, MTKViewDelegate, MetalTouchDelegate {
  let parent: MetalView
  let device: MTLDevice!
  let commandQueue: MTLCommandQueue
  var vertexDescriptor: MTLVertexDescriptor!
  var renderPipeline: MTLRenderPipelineState!
  var depthStencilState: MTLDepthStencilState!
  var vertexBuffer: MTLBuffer!
  var meshes: [MTKMesh] = []
  
  var modelOrientation: simd_quatf = simd_quatf(simd_float3x3(1))
  var touchDownOrientation: simd_quatf = simd_quatf(simd_float3x3(1))

  var modelCenter: [Float] = [0, 0, 0]
  var modelSize: [Float] = [1, 1, 1]

  // must set mtkView
  var mtkView: MTKGestureView? {
//  var mtkView: MTKTouchView? {
//  var mtkView: MTKMouseView? {
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
        // touch delegate
        mtkView.touchDelegate = self
        loadResources()
        buildPipeline(view: mtkView)
      }
    }
  }

  init(_ parent: MetalView) {
    self.parent = parent
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!
    super.init()
  }
  
  func didPress() {
    touchDownOrientation = modelOrientation
  }
  
  func didDrag(x: Float, y: Float) {
    let magnitude = sqrt(x * x + y * y)
    let currentMatrix = simd_float4x4(touchDownOrientation)
    let screenVector = simd_float4(-y / magnitude, x / magnitude, 0, 1)
    let touchVector = screenVector * currentMatrix
    let axis = SIMD3<Float>(touchVector.x, touchVector.y, touchVector.z)
//    let frame = mtkView?.frame ?? NSRect.init(x: 0, y: 0, width: 100, height: 100)
    let frame = mtkView!.frame
    let smallSize = Float(frame.width < frame.height ? frame.width : frame.height)
    // todo, make rotation angle magnitude a factor based on the screen pixel size
    let rotation = simd_quatf(angle: 3 * magnitude / smallSize, axis: axis)
    modelOrientation = touchDownOrientation * rotation
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

    let depthDesecriptor = MTLDepthStencilDescriptor()
    depthDesecriptor.depthCompareFunction = .lessEqual
    depthDesecriptor.isDepthWriteEnabled = true
    self.depthStencilState = device.makeDepthStencilState(descriptor: depthDesecriptor)

    let boundingBox = asset.boundingBox
    self.modelSize = [0, 1, 2].map { boundingBox.maxBounds[$0] - boundingBox.minBounds[$0] }
    self.modelCenter = [0, 1, 2].map { boundingBox.minBounds[$0] + self.modelSize[$0] / 2 }
//    analyzeMesh(mesh: meshes[0])
//    self.modelCenter = dimensions.0
//    self.modelSize = dimensions.1

//    MDLMeshBufferAllocator
//    MDLMeshBuffer
//    MDLSubmesh(indexBuffer: <#T##MDLMeshBuffer#>, indexCount: <#T##Int#>, indexType: <#T##MDLIndexBitDepth#>, geometryType: <#T##MDLGeometryType#>, material: <#T##MDLMaterial?#>)
//    MDLMesh(vertexBuffer: <#T##MDLMeshBuffer#>, vertexCount: <#T##Int#>, descriptor: <#T##MDLVertexDescriptor#>, submeshes: <#T##[MDLSubmesh]#>)

//    addNormals(withAttributeNamed:creaseThreshold:)

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
  
  func analyzeMesh(mesh: MTKMesh) {
//    print("analysis count vert \(mesh.vertexCount) submesh \(mesh.submeshes.count)")
    let verts = mesh.vertexBuffers[0]
//    print("Analysis \(verts.length) \(verts.name) \(verts.offset)")
    let vertices = verts.buffer.contents().bindMemory(to: Float.self, capacity: mesh.vertexCount * 3)
    print("vertices 0 1 2 \(vertices[0]) \(vertices[1]) \(vertices[2])")
    print("vertices 3 4 5 \(vertices[3]) \(vertices[4]) \(vertices[5])")
    print("vertices 6 7 8 \(vertices[6]) \(vertices[7]) \(vertices[8])")
    var mins = [Float.infinity, Float.infinity, Float.infinity]
    var maxs = [-Float.infinity, -Float.infinity, -Float.infinity]
    for i in 0..<mesh.vertexCount {
      if vertices[i*8+0] > maxs[0] { maxs[0] = vertices[i*8+0] }
      if vertices[i*8+1] > maxs[1] { maxs[1] = vertices[i*8+1] }
      if vertices[i*8+2] > maxs[2] { maxs[2] = vertices[i*8+2] }
      if vertices[i*8+0] < mins[0] { mins[0] = vertices[i*8+0] }
      if vertices[i*8+1] < mins[1] { mins[1] = vertices[i*8+1] }
      if vertices[i*8+2] < mins[2] { mins[2] = vertices[i*8+2] }
    }
//    print("maxs \(maxs)")
//    print("mins \(mins)")
//
//    let bounds = [0, 1, 2].map { maxs[$0] - mins[$0] }
//    let center = [0, 1, 2].map { mins[$0] + (bounds[$0] / 2) }
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

    let commandBuffer = commandQueue.makeCommandBuffer()!
    if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
      let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
      
//      time += 1 / Float(view.preferredFramesPerSecond)
      let centerMatrix = float4x4(translationBy: SIMD3<Float>(-modelCenter[0],
                                                              -modelCenter[1],
                                                              -modelCenter[2]))
//      let modelCenter = float4x4(translationBy: SIMD3<Float>(center[0], center[1], center[2]))
      
      let modelMatrix = float4x4(modelOrientation)
//      let modelMatrix = float4x4(rotationAbout: SIMD3<Float>(0, 1, 0), by: angle)
//      let viewMatrix = float4x4(translationBy: SIMD3<Float>(0, -0.1, -0.2))
      let viewMatrix = float4x4(translationBy: SIMD3<Float>(0, 0, -0.2))
//      let viewMatrix = float4x4(translationBy: SIMD3<Float>(-center[0], -center[1], -center[2]))
      let modelViewMatrix = viewMatrix * (modelMatrix * centerMatrix)
      let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
      let projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.01, farZ: 100)
      var uniforms = Uniforms(modelViewMatrix: modelViewMatrix, projectionMatrix: projectionMatrix)
      commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)

      commandEncoder.setRenderPipelineState(renderPipeline)
      commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
      
      commandEncoder.setDepthStencilState(depthStencilState)

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
