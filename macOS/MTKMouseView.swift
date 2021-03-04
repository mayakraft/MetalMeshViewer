//
//  MTKTouchView.swift
//  MeshViewer (macOS)
//
//  Created by Robby on 3/3/21.
//

import AppKit
import MetalKit

class MTKMouseView: MTKGestureView {
  var touchDown: NSPoint = .zero

  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    touchDown = event.locationInWindow
    touchDelegate?.didPress()
  }

  override func mouseDragged(with event: NSEvent) {
    super.mouseDragged(with: event)
    touchDelegate?.didDrag(x: Float(event.locationInWindow.x - touchDown.x),
                           y: Float(event.locationInWindow.y - touchDown.y))
  }
}
