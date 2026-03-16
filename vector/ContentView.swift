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
    case settings
    case aliases
    case scripts
    case projects
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
            case .settings:
                SettingsPage(page: $page)
            case .aliases:
                AliasesPage(page: $page)
            case .scripts:
                ScriptsPage(page: $page)
            case .projects:
                ProjectsPage(page: $page)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .changePage)) { notification in
            if let pageRaw = notification.userInfo?["page"] as? String,
               let targetPage = AppSettingsCommand.AppPage(rawValue: pageRaw) {
                switch targetPage {
                case .settings:
                    page = .settings
                case .aliases:
                    page = .aliases
                case .scripts:
                    page = .scripts
                case .projects:
                    page = .projects
                }
            }
        }
    }
}

#Preview {
    RootView()
}
