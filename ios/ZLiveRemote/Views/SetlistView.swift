import SwiftUI

struct SetlistView: View {
    @ObservedObject var viewModel: LiveRemoteViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    private let cornerRadius: CGFloat = 4

    private var palette: AppPalette {
        AppPalette(theme: themeManager.theme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.songs) { song in
                        Button {
                            viewModel.select(song: song)
                        } label: {
                            row(for: song)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(palette.line, lineWidth: 1)
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(palette.background)
            .navigationTitle("SETLIST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
        }
        .foregroundStyle(palette.text)
    }

    private func row(for song: Song) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(viewModel.currentSong == song ? palette.accent : .clear)
                .frame(width: 3)

            Text(String(format: "%02d", song.id + 1))
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(palette.muted)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                if !song.sounds.isEmpty {
                    Text(song.sounds.joined(separator: " · "))
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if viewModel.currentSong == song {
                Text(viewModel.playbackState == .playing ? "SONANDO" : "PREPARADA")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(
                        viewModel.playbackState == .playing
                            ? palette.playing
                            : palette.ready
                    )
            }
        }
        .padding(.trailing, 12)
        .frame(minHeight: 54)
        .background(palette.surface)
        .overlay(alignment: .top) {
            if song.id > viewModel.songs.first?.id ?? 0 {
                Rectangle()
                    .fill(palette.line)
                    .frame(height: 1)
                    .padding(.leading, 41)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    SetlistView(viewModel: LiveRemoteViewModel())
        .environmentObject(ThemeManager())
}
