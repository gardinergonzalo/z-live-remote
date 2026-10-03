import SwiftUI

struct ShowView: View {
    @ObservedObject var viewModel: LiveRemoteViewModel

    private let background = Color(red: 0.03, green: 0.04, blue: 0.06)
    private let panel = Color(red: 0.06, green: 0.08, blue: 0.11)
    private let border = Color.white.opacity(0.08)
    private let accent = Color(red: 0.46, green: 0.36, blue: 1.0)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    appHeader

                    if let song = viewModel.currentSong {
                        nowPlayingCard(song)
                        nextSongCard
                        navigationControls
                        bottomControls
                    } else {
                        disconnectedCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var appHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Z LIVE REMOTE")
                    .font(.system(size: 15, weight: .black))
                    .tracking(0.4)

                Text("Ableton Live 12 Suite")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 7, height: 7)

                Text(connectionLabel)
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(connectionColor.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(connectionColor.opacity(0.28), lineWidth: 1)
            }
            .foregroundStyle(connectionColor)
        }
        .padding(.top, 8)
    }

    private func nowPlayingCard(_ song: Song) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 8, height: 8)

                    Text(viewModel.playbackState.rawValue)
                        .font(.system(size: 12, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(stateColor)
                }

                Spacer()

                Text(viewModel.currentDisplayNumber)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }

            Text(song.name)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(-1.3)
                .lineLimit(2)
                .minimumScaleFactor(0.58)
                .allowsTightening(true)
                .padding(.top, 18)

            Text(viewModel.playbackState == .playing ? "La canción está sonando" : "Lista para disparar")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            if !song.sounds.isEmpty {
                Text("SONIDOS")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                    .padding(.bottom, 9)

                FlowLayout(spacing: 8) {
                    ForEach(Array(song.sounds.enumerated()), id: \.offset) { index, sound in
                        HStack(spacing: 7) {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.secondary)

                            Text(sound)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(border, lineWidth: 1)
                        }
                    }
                }
            }

            Button {
                viewModel.fire()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.playbackState == .playing ? "waveform" : "play.fill")
                    Text(viewModel.playbackState == .playing ? "REPRODUCIENDO" : "DISPARAR")
                }
                .font(.system(size: 20, weight: .black))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 88)
                .background(fireButtonBackground, in: RoundedRectangle(cornerRadius: 22))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.playbackState == .playing)
            .padding(.top, 20)
        }
        .padding(20)
        .background(panel, in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(border, lineWidth: 1)
        }
    }

    private var nextSongCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SIGUIENTE")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)

                Text(viewModel.nextSong?.name ?? "FIN DE SETLIST")
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let sounds = viewModel.nextSong?.sounds, !sounds.isEmpty {
                    Text(sounds.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(border, lineWidth: 1)
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 10) {
            secondaryButton(title: "ANTERIOR", systemImage: "arrow.left") {
                viewModel.selectPrevious()
            }

            secondaryButton(title: "SIGUIENTE", systemImage: "arrow.right") {
                viewModel.selectNext()
            }
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.isSetlistPresented = true
            } label: {
                Label("SETLIST", systemImage: "list.bullet")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(panel, in: RoundedRectangle(cornerRadius: 17))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(border, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Text("MANTENER STOP")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.red.opacity(0.82))
                .frame(width: 138, height: 54)
                .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
                .overlay {
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(Color.red.opacity(0.20), lineWidth: 1)
                }
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.8) {
                    viewModel.stop()
                }
        }
    }

    private var disconnectedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text("SIN CONEXIÓN")
                .font(.headline)

            Text("Esperando datos de Ableton.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(panel, in: RoundedRectangle(cornerRadius: 24))
    }

    private func secondaryButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if systemImage == "arrow.left" {
                    Image(systemName: systemImage)
                }

                Text(title)

                if systemImage == "arrow.right" {
                    Image(systemName: systemImage)
                }
            }
            .font(.system(size: 13, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(panel, in: RoundedRectangle(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var stateColor: Color {
        switch viewModel.playbackState {
        case .ready:
            return Color(red: 1.0, green: 0.72, blue: 0.30)
        case .playing:
            return Color(red: 0.18, green: 0.84, blue: 0.48)
        case .disconnected:
            return .secondary
        }
    }

    private var connectionColor: Color {
        viewModel.playbackState == .disconnected
            ? Color.red.opacity(0.82)
            : Color(red: 0.18, green: 0.84, blue: 0.48)
    }

    private var connectionLabel: String {
        viewModel.playbackState == .disconnected ? "SIN CONEXIÓN" : "CONECTADO"
    }

    private var fireButtonBackground: some ShapeStyle {
        if viewModel.playbackState == .playing {
            return AnyShapeStyle(Color(red: 0.12, green: 0.62, blue: 0.34))
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    accent,
                    Color(red: 0.30, green: 0.50, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ShowView(viewModel: LiveRemoteViewModel())
        .preferredColorScheme(.dark)
}
