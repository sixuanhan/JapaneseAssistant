//
//  Japanese_AssistantApp.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 12/19/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    // Explicitly enable Firestore's on-disk cache so reads/writes work
    // offline and queued writes replay when the network comes back.
    let settings = FirestoreSettings()
    settings.cacheSettings = PersistentCacheSettings()
    Firestore.firestore().settings = settings

    return true
  }
}

@main
struct Japanese_AssistantApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
//            DebugToolsView() // ← just for testing
        }
        .onChange(of: scenePhase) { _, newPhase in
            // When the app comes back to the foreground, opportunistically
            // sync with Firestore. No-op when offline; the SDK queues writes
            // and replays them once connectivity returns.
            if newPhase == .active {
                Task { await authViewModel.syncWithCloud() }
            }
        }
    }
}
