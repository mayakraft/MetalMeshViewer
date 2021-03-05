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
  var depthStencilState: MTLDepthStencilState!
  var renderPipeline: MTLRenderPipelineState!
  var camera: Camera!
  var model: Model!

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

        camera = Camera(view: mtkView)
        model = Model(device: device, view: mtkView)

        // load a model. this can happen later, asynchronously
        if let url = Bundle.main.url(forResource: "bunny", withExtension: "obj") {
          loadOBJ(url: url)
        } else {
          fatalError("file not found")
        }
      }
    }
  }

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
  
  func loadOBJ(url: URL) {
    do {
      guard let mtkView = self.mtkView else { fatalError("mtkView before mesh") }
      try model.loadResources(url: url)
      // after a model is successfully loaded
      // build a pipeline using the mesh
      buildPipeline(view: mtkView, vertexDescriptor: model.vertexDescriptor)
      // set the camera zoom to fit the model
      camera.modelBounds = model.asset.boundingBox
    } catch let error{
      fatalError(error.localizedDescription)
    }
  }
  
  func buildPipeline(view: MTKView, vertexDescriptor: MTLVertexDescriptor) {
    guard let library = device.makeDefaultLibrary() else { fatalError("make library") }
    let vertexFunction = library.makeFunction(name: "vertex_main")
    let fragmentFunction = library.makeFunction(name: "fragment_main")
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    pipelineDescriptor.vertexDescriptor = vertexDescriptor
    do {
      renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch let error {
      fatalError("Could not create render pipeline state object \(error)")
    }
  }
  
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    print("mtkView drawableSizeWillChange not implemented")
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let renderPassDescriptor = view.currentRenderPassDescriptor,
          let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
      else { return }

    commandEncoder.setDepthStencilState(depthStencilState)
    var uniforms = Uniforms(modelViewMatrix: camera.modelView,
                            projectionMatrix: camera.projection)
    commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
    commandEncoder.setRenderPipelineState(renderPipeline)
    model.draw(commandEncoder: commandEncoder)
    commandEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
