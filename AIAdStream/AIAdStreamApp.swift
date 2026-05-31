import SwiftUI

@main
struct AIAdStreamApp: App {
    @StateObject private var feedViewModel = FeedViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(feedViewModel)
        }
    }
}
