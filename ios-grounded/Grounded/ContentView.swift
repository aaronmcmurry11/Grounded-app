//
//  ContentView.swift
//  Grounded
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .environment(RemedyLibrary())
        .preferredColorScheme(.dark)
}
