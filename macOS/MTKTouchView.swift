//
//  MTKTouchView.swift
//  MeshViewer (macOS)
//
//  Created by Robby on 3/3/21.
//

import AppKit
import MetalKit

protocol MetalTouchDelegate {
//  func didPress(x: Float, y: Float)
  func didPress()
  func didDrag(x: Float, y: Float)
}

class MTKTouchView: MTKView {
  
  var touchDown: NSPoint = .zero
  var touchDelegate: MetalTouchDelegate?
  // some kind of start press position

  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    touchDown = event.locationInWindow
    touchDelegate?.didPress()
  }

//  override func mouseUp(with event: NSEvent) {
//    super.mouseUp(with: event)
//  }
  
  override func mouseDragged(with event: NSEvent) {
    super.mouseDragged(with: event)
    touchDelegate?.didDrag(x: Float(event.locationInWindow.x - touchDown.x),
                           y: Float(event.locationInWindow.y - touchDown.y))
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)
    print("mouseMoved")
  }

  override func touchesBegan(with event: NSEvent) {
    super.touchesBegan(with: event)
    print("touchesBegan")
  }
  
  override func touchesMoved(with event: NSEvent) {
    super.touchesMoved(with: event)
    print("touchesMoved")
  }

  override func touchesEnded(with event: NSEvent) {
    super.touchesEnded(with: event)
    print("touchesEnded")
  }
  
  override func touchesCancelled(with event: NSEvent) {
    super.touchesCancelled(with: event)
    print("touchesCancelled")
  }
  
}
