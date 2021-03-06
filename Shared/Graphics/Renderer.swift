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
  var renderPipeline: MTLRenderPipelineState?
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

        // this demonstrates a couple ways of loading a model
        // they happen asynchronously, so, continue initialization
        // inside the completion handler
        loadModel { (model) in
          self.model = model
          // after a model is successfully loaded
          // build a pipeline using the mesh
          self.buildPipeline(view: mtkView, vertexDescriptor: model.vertexDescriptor)
          // set the camera zoom to fit the model
         self.camera.modelBounds = model.boundingBox
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

  // please uncomment only one of these options
  func loadModel(completionHandler: ((Model) -> Void)?) {
    // OPTION 1: load a mesh from raw data
//    let modelRaw = ModelRaw(device: device,
//                            vertices: [
//                               0.670052, -0.112482,  0.625544,
//                              -0.670354, -0.112482,  0.625545,
//                              -0.692439, -0.168617, -0.547186,
//                               0.692135, -0.168618, -0.547187,
//                              -0.703304,  0.257409,  0.031942,
//                               0.703002,  0.257409,  0.031940,
//                              -0.000151, -0.021667, -0.657468,
//                              -0.000150,  0.288686, -0.024483,
//                              -0.000150, -0.219627,  0.467529,
//                            ],
//                            triangles: [7,8,0, 7,0,5, 7,4,1, 7,1,8, 7,6,2, 7,2,4, 7,5,3, 7,3,6])
//    completionHandler?(modelRaw)

    // OPTION 2: load a mesh from a file
    guard let url = Bundle.main.url(forResource: "bunny", withExtension: "obj") else {
      print("file not found")
      return
    }
    let modelFile = ModelFile(device: device, file: url)
    completionHandler?(modelFile)


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
    // vertexDescriptor comes from the mesh
    pipelineDescriptor.vertexDescriptor = vertexDescriptor
    do {
      renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch let error {
      fatalError("Could not create render pipeline state object \(error)")
    }
  }
  
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
          let renderPipeline = self.renderPipeline,
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
