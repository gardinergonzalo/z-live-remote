import SwiftUI

struct ShowView: View {
    @ObservedObject var viewModel: LiveRemoteViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    private let cornerRadius: CGFloat = 4

    private var palette: AppPalette {
        AppPalette(theme: themeManager.theme)
    }

    var body: some View {
        ZStack {
            palette.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    appHeader

                    if let song = viewModel.currentSong {
                        currentSongPanel(song)
                        nextSongPanel
                        navigationControls
                        bottomControls
                    } else {
                        disconnectedPanel
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(palette.text)
    }

    private var appHeader: some View {
        HStack(spacing: 10) {
            Text("Z LIVE REMOTE")
                .font(.system(size: 13, weight: .bold))
                .tracking(0.35)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 7, height: 7)

                Text(connectionLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.muted)
            }

            Button {
                themeManager.toggle()
            } label: {
                Image(systemName: themeManager.theme.toggleIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 28)
                    .background(palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(palette.line, lineWidth: 1)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(themeManager.theme.toggleAccessibilityLabel)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func currentSongPanel(_ song: Song) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(viewModel.playbackState.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.25)
                    .foregroundStyle(stateColor)

                Spacer()

                Text(viewModel.currentDisplayNumber)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.muted)
            }

            Text(song.name)
                .font(.system(size: 31, weight: .bold))
                .tracking(-0.8)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .padding(.top, 18)

            Text(viewModel.playbackState == .playing ? "La canción está sonando" : "Lista para disparar")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(palette.muted)
                .padding(.top, 6)

            if !song.sounds.isEmpty {
                Rectangle()
                    .fill(palette.line)
                    .frame(height: 1)
                    .padding(.vertical, 16)

                Text("SONIDOS / REFERENCIAS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.muted)
                    .padding(.bottom, 4)

                VStack(spacing: 0) {
                    ForEach(Array(song.sounds.enumerated()), id: \.offset) { index, sound in
                        HStack(spacing: 10) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 10, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(palette.muted)
                                .frame(width: 22, alignment: .leading)

                            Text(sound)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(2)

                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 36)
                        .overlay(alignment: .top) {
                            if index > 0 {
                                Rectangle()
                                    .fill(palette.line)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
            }

            Button {
                viewModel.fire()
            } label: {
                Text(viewModel.playbackState == .playing ? "REPRODUCIENDO" : "DISPARAR")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 64)
                    .background(fireBackground)
                    .foregroundStyle(fireForeground)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(fireBorder, lineWidth: 1)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.playbackState == .playing)
            .padding(.top, 16)
        }
        .padding(16)
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    private var nextSongPanel: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SIGUIENTE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.muted)

                Text(viewModel.nextSong?.name ?? "FIN DE SETLIST")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let sounds = viewModel.nextSong?.sounds, !sounds.isEmpty {
                    Text(sounds.joined(separator: " · "))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    private var navigationControls: some View {
        HStack(spacing: 8) {
            secondaryButton(title: "ANTERIOR", systemImage: "arrow.left") {
                viewModel.selectPrevious()
            }

            secondaryButton(title: "SIGUIENTE", systemImage: "arrow.right") {
                viewModel.selectNext()
            }
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.isSetlistPresented = true
            } label: {
                Text("SETLIST")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(panelBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(palette.line, lineWidth: 1)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
            .buttonStyle(.plain)

            Text("MANTENER STOP")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(palette.danger)
                .frame(width: 130, height: 48)
                .background(panelBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(palette.line, lineWidth: 1)
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.8) {
                    viewModel.stop()
                }
                .accessibilityLabel("Mantener para detener")
        }
    }

    private var disconnectedPanel: some View {
        VStack(spacing: 10) {
            Text("SIN CONEXIÓN")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(palette.danger)

            Text("Esperando datos de Ableton.")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    private func secondaryButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if systemImage == "arrow.left" {
                    Image(systemName: systemImage)
                }

                Text(title)

                if systemImage == "arrow.right" {
                    Image(systemName: systemImage)
                }
            }
            .font(.system(size: 12, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(panelBackground)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.line, lineWidth: 1)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var panelBackground: Color {
        palette.surface
    }

    private var stateColor: Color {
        switch viewModel.playbackState {
        case .ready:
            return palette.ready
        case .playing:
            return palette.playing
        case .disconnected:
            return palette.muted
        }
    }

    private var connectionColor: Color {
        viewModel.playbackState == .disconnected ? palette.danger : palette.playing
    }

    private var connectionLabel: String {
        viewModel.playbackState == .disconnected ? "SIN CONEXIÓN" : "CONECTADO"
    }

    private var fireBackground: Color {
        viewModel.playbackState == .playing ? .clear : palette.accent
    }

    private var fireForeground: Color {
        viewModel.playbackState == .playing ? palette.playing : Color(red: 0.09, green: 0.09, blue: 0.09)
    }

    private var fireBorder: Color {
        viewModel.playbackState == .playing ? palette.playing : palette.accent
    }
}

#Preview {
    ShowView(viewModel: LiveRemoteViewModel())
        .environmentObject(ThemeManager())
}
