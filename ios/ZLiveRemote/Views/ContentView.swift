import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LiveRemoteViewModel()

    var body: some View {
        ShowView(viewModel: viewModel)
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
