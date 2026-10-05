import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LiveRemoteViewModel(
        songs: [],
        initialIndex: 0,
        playbackState: .disconnected
    )

    var body: some View {
        ShowView(viewModel: viewModel)
            .onAppear {
                viewModel.startRemoteConnection()
            }
            .sheet(isPresented: $viewModel.isSetlistPresented) {
                SetlistView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
}
