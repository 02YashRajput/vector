//
//  vectorApp.swift
//  vector
//
//  Created by Yash Rajput on 13/03/26.
//

import SwiftUI

@main
struct vectorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
