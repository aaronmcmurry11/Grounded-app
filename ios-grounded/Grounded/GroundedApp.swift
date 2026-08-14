//
//  GroundedApp.swift
//  Grounded
//

import SwiftUI

@main
struct GroundedApp: App {
    @State private var appModel = AppModel()
    @State private var library = RemedyLibrary()

    init() {
        Typography.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(library)
                .preferredColorScheme(.dark)
        }
    }
}
