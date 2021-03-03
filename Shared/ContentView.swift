//
//  ContentView.swift
//  Shared
//
//  Created by Robby on 3/2/21.
//

import SwiftUI

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
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
