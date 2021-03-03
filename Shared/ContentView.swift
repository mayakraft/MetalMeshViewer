//
//  ContentView.swift
//  Shared
//
//  Created by Robby on 3/2/21.
//

import SwiftUI

// make a visual effects view, but only on MacOS
#if os(iOS)
struct VisualEffectView: UIViewRepresentable {
  func makeUIView(context: Context) -> some UIView {
    UIView()
  }
  func updateUIView(_ uiView: UIViewType, context: Context) { }
}
#else
struct VisualEffectView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.blendingMode = .behindWindow
    view.isEmphasized = true
    view.material = .popover // .underWindowBackground
    return view
  }
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}
#endif

struct ContentView: View {
  var body: some View {
    MetalView()
      .frame(minWidth: 0,
             idealWidth: 600,
             maxWidth: .infinity,
             minHeight: 0,
             idealHeight: 600,
             maxHeight: .infinity,
             alignment: .center)
      .background(VisualEffectView())
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
