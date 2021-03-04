//
//  MTKTouchView.swift
//  MeshViewer (macOS)
//
//  Created by Robby on 3/3/21.
//

import UIKit
import MetalKit

class MTKTouchView: MTKGestureView {
  var touchDown: CGPoint = .zero

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    if let touch = touches.first?.location(in: self) {
      touchDown = touch
    }
    touchDelegate?.didPress()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    guard let touch = touches.first?.location(in: self) else { return }
    touchDelegate?.didDrag(x: Float(touch.x - touchDown.x),
                           y: -Float(touch.y - touchDown.y))
  }
}
