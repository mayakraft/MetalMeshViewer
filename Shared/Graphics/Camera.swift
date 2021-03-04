//
//  Camera.swift
//  MeshViewer
//
//  Created by Robby on 3/4/21.
//

import Foundation
import MetalKit
import simd

class Camera: NSObject, MetalTouchDelegate {
  internal let mtkView: MTKView
  var modelOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
  internal var touchDownOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
  internal var modelCenter: SIMD3<Float> = [0, 0, 0]
  internal var modelRadius: Float = 1 // half the largest diameter (largest along one axis)

  init(with view:MTKView) {
    mtkView = view
    super.init()
  }
  
  // MARK: setters

  var modelBounds: MDLAxisAlignedBoundingBox =
      MDLAxisAlignedBoundingBox(maxBounds: [1, 1, 1],
                                minBounds: [-1, -1, -1]) {
    didSet {
      let modelSize = [0, 1, 2].map { modelBounds.maxBounds[$0] - modelBounds.minBounds[$0] }
      self.modelRadius = modelSize.max()!
      [0, 1, 2].map { modelBounds.minBounds[$0] + modelSize[$0] / 2 }
        .enumerated()
        .forEach { self.modelCenter[$0.offset] = $0.element }
    }
  }
  
  // MARK: getters

  var projection: simd_float4x4 {
    get {
      let aspectRatio = Float(mtkView.drawableSize.width / mtkView.drawableSize.height)
      return float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.01, farZ: 100)
    }
  }
  
  var modelView: simd_float4x4 {
    get {
      let centerMatrix = float4x4(translationBy: -1 * modelCenter)
      let modelMatrix = float4x4(modelOrientation)
      let viewMatrix = float4x4(translationBy: SIMD3<Float>(0, 0, -1.25 * self.modelRadius))
      return viewMatrix * (modelMatrix * centerMatrix)
    }
  }
  
  // MARK: MetalView touch delegate
  
  func didPress() {
    touchDownOrientation = modelOrientation
  }

  func didDrag(x: Float, y: Float) {
    let magnitude = sqrt(x * x + y * y)
    let currentMatrix = simd_float4x4(touchDownOrientation)
    let screenVector = simd_float4(-y / magnitude, x / magnitude, 0, 1)
    let touchVector = screenVector * currentMatrix
    let axis = SIMD3<Float>(touchVector.x, touchVector.y, touchVector.z)
    let frame = mtkView.frame
    let smallSize = Float(frame.width < frame.height ? frame.width : frame.height)
    let rotation = simd_quatf(angle: 3 * magnitude / smallSize, axis: axis)
    modelOrientation = touchDownOrientation * rotation
  }
}
