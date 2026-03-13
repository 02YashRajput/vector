//
//  ContentView.swift
//  vector
//
//  Created by Yash Rajput on 13/03/26.
//

import SwiftUI
import AppKit

enum Page {
    case search
    case onboarding
}

struct RootView: View {
    @State private var page: Page = UserDefaults.standard.bool(forKey: "is_onboarding_complete") ? .search : .onboarding

    var body: some View {
        ZStack {
            switch page {
            case .search:
                SearchPage(page: $page)
            case .onboarding:
                OnBoardingPage(page: $page)
            }
        }
    }
}

#Preview {
    RootView()
}
