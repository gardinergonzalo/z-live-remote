import SwiftUI
import UIKit

struct ShowView: View {
    @ObservedObject var viewModel: LiveRemoteViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    private let cornerRadius: CGFloat = 4

    private var palette: AppPalette {
        AppPalette(theme: themeManager.theme)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                palette.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        appHeader

                        if let song = viewModel.currentSong {
                            if usesTwoColumnLayout(geometry.size) {
                                HStack(alignment: .top, spacing: 10) {
                                    currentSongPanel(song)
                                        .frame(maxWidth: .infinity)

                                    VStack(spacing: 10) {
                                        nextSongPanel
                                        navigationControls

                                        if showsPersistentSetlist(geometry.size) {
                                            persistentSetlist
                                        } else {
                                            setlistButton
                                        }
                                    }
                                    .frame(
                                        width: min(
                                            max(300, geometry.size.width * 0.36),
                                            410
                                        )
                                    )
                                }
                            } else {
                                currentSongPanel(song)
                                nextSongPanel
                                navigationControls
                                setlistButton
                            }
                        } else {
                            disconnectedPanel
                        }
                    }
                    .padding(.horizontal, horizontalPadding(for: geometry.size))
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(palette.text)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var appHeader: some View {
        HStack(spacing: 9) {
            AbletonMark()
                .fill(palette.text)
                .frame(width: 25, height: 25)

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
                    .frame(width: 34, height: 32)
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
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(stateColor)

                Spacer()

                Text(viewModel.currentDisplayNumber)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.muted)
            }

            Text(song.name)
                .font(.system(size: 36, weight: .black))
                .tracking(-1.0)
                .lineLimit(2)
                .minimumScaleFactor(0.58)
                .allowsTightening(true)
                .padding(.top, 18)

            Text(
                viewModel.playbackState == .playing
                    ? "La canción está sonando"
                    : "Lista para disparar"
            )
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(palette.muted)
            .padding(.top, 7)

            if !song.sounds.isEmpty {
                Rectangle()
                    .fill(palette.line)
                    .frame(height: 1)
                    .padding(.vertical, 18)

                Text("REFERENCIAS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.35)
                    .foregroundStyle(palette.muted)
                    .padding(.bottom, 6)

                VStack(spacing: 0) {
                    ForEach(Array(song.sounds.enumerated()), id: \.offset) { index, sound in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(palette.muted)
                                .frame(width: 28, alignment: .leading)

                            Text(sound)
                                .font(.system(size: 23, weight: .semibold))
                                .tracking(-0.25)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)

                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 48)
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

            if viewModel.hasTimeline {
                timelineView
                    .padding(.top, 18)
            }

            playbackControls
                .padding(.top, 18)
        }
        .padding(18)
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    private var timelineView: some View {
        VStack(spacing: 8) {
            HStack {
                Text(formatTime(viewModel.timelineElapsed))
                Spacer()
                Text("−" + formatTime(viewModel.timelineRemaining))
            }
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(palette.muted)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.surfaceSecondary)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            viewModel.playbackState == .playing
                                ? palette.playing
                                : palette.accent
                        )
                        .frame(
                            width: max(
                                0,
                                proxy.size.width * CGFloat(viewModel.timelineProgress)
                            )
                        )
                }
            }
            .frame(height: 7)
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(palette.line, lineWidth: 1)
            }
            .accessibilityLabel("Progreso de la canción")
            .accessibilityValue(
                "\(formatTime(viewModel.timelineElapsed)) de \(formatTime(viewModel.timelineDuration))"
            )
        }
    }

    @ViewBuilder
    private var playbackControls: some View {
        if viewModel.playbackState == .playing {
            VStack(spacing: 8) {
                Text("REPRODUCIENDO")
                    .font(.system(size: 17, weight: .black))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 62)
                    .background(palette.playing)
                    .foregroundStyle(Color(red: 0.03, green: 0.13, blue: 0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(palette.playing, lineWidth: 1)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )

                Text("MANTENER STOP")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 58)
                    .background(palette.danger)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(palette.danger, lineWidth: 1)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.8) {
                        viewModel.stop()
                    }
                    .accessibilityLabel("Mantener para detener la canción")
            }
        } else {
            Button {
                viewModel.fire()
            } label: {
                Text("DISPARAR")
                    .font(.system(size: 18, weight: .black))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 70)
                    .background(palette.accent)
                    .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(palette.accent, lineWidth: 1)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var nextSongPanel: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SIGUIENTE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.muted)

                Text(viewModel.nextSong?.name ?? "FIN DE SETLIST")
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let sounds = viewModel.nextSong?.sounds, !sounds.isEmpty {
                    Text(sounds.joined(separator: " · "))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.muted)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
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

    private var setlistButton: some View {
        Button {
            viewModel.isSetlistPresented = true
        } label: {
            Label("SETLIST", systemImage: "list.bullet")
                .font(.system(size: 12, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
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

    private var persistentSetlist: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SETLIST")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(palette.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            ForEach(viewModel.songs) { song in
                Button {
                    viewModel.select(song: song)
                } label: {
                    HStack(spacing: 9) {
                        Rectangle()
                            .fill(
                                viewModel.currentSong == song
                                    ? palette.accent
                                    : Color.clear
                            )
                            .frame(width: 3)

                        Text(String(format: "%02d", song.id + 1))
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(palette.muted)
                            .frame(width: 28, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)

                            if !song.sounds.isEmpty {
                                Text(song.sounds.joined(separator: " · "))
                                    .font(.system(size: 9))
                                    .foregroundStyle(palette.muted)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 4)

                        if viewModel.currentSong == song {
                            Text(
                                viewModel.playbackState == .playing
                                    ? "SONANDO"
                                    : "PREPARADA"
                            )
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(
                                viewModel.playbackState == .playing
                                    ? palette.playing
                                    : palette.ready
                            )
                        }
                    }
                    .frame(minHeight: 46)
                    .padding(.trailing, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(palette.line)
                        .frame(height: 1)
                        .padding(.leading, 40)
                }
            }
        }
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
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
            .frame(height: 52)
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

    private func usesTwoColumnLayout(_ size: CGSize) -> Bool {
        size.width >= 680
    }

    private func showsPersistentSetlist(_ size: CGSize) -> Bool {
        size.width >= 950
    }

    private func horizontalPadding(for size: CGSize) -> CGFloat {
        size.width >= 700 ? 18 : 14
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }

        let rounded = Int(seconds.rounded())
        let minutes = rounded / 60
        let remainingSeconds = rounded % 60

        return String(format: "%d:%02d", minutes, remainingSeconds)
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
        viewModel.isConnected ? palette.playing : palette.danger
    }

    private var connectionLabel: String {
        viewModel.isConnected ? "CONECTADO" : "SIN CONEXIÓN"
    }
}

private struct AbletonMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let verticalWidth = rect.width * 0.075
        let verticalGap = rect.width * 0.07
        let verticalHeight = rect.height * 0.60
        let top = rect.minY + rect.height * 0.12

        for index in 0..<4 {
            let x = rect.minX + CGFloat(index) * (verticalWidth + verticalGap)
            path.addRect(
                CGRect(
                    x: x,
                    y: top,
                    width: verticalWidth,
                    height: verticalHeight
                )
            )
        }

        let horizontalX = rect.minX + rect.width * 0.58
        let horizontalWidth = rect.width * 0.42
        let horizontalHeight = rect.height * 0.075
        let horizontalGap = rect.height * 0.09

        for index in 0..<4 {
            let y = rect.minY + rect.height * 0.12
                + CGFloat(index) * (horizontalHeight + horizontalGap)
            path.addRect(
                CGRect(
                    x: horizontalX,
                    y: y,
                    width: horizontalWidth,
                    height: horizontalHeight
                )
            )
        }

        return path
    }
}

#Preview {
    ShowView(viewModel: LiveRemoteViewModel())
        .environmentObject(ThemeManager())
}
