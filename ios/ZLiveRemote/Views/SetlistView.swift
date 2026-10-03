import SwiftUI

struct SetlistView: View {
    @ObservedObject var viewModel: LiveRemoteViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.songs) { song in
                Button {
                    viewModel.select(song: song)
                } label: {
                    HStack(spacing: 12) {
                        Text(String(format: "%02d", song.id + 1))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(
                                    viewModel.currentSong == song
                                        ? Color(red: 0.72, green: 0.66, blue: 1.0)
                                        : .primary
                                )

                            if !song.sounds.isEmpty {
                                Text(song.sounds.joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if viewModel.currentSong == song {
                            Text(viewModel.playbackState == .playing ? "SONANDO" : "PREPARADA")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                                .background(Color.orange.opacity(0.08), in: Capsule())
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Setlist")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SetlistView(viewModel: LiveRemoteViewModel())
        .preferredColorScheme(.dark)
}
