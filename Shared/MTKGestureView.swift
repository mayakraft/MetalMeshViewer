//
//  MTKGestureView.swift
//  MeshViewer
//
//  Created by Robby on 3/4/21.
//

import MetalKit

protocol MetalTouchDelegate {
  func didPress()
  func didDrag(x: Float, y: Float)
}

class MTKGestureView: MTKView {
  var touchDelegate: MetalTouchDelegate?
}
