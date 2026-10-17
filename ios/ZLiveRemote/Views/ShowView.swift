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

                if
                    showsPersistentSetlist(geometry.size),
                    let song = viewModel.currentSong
                {
                    tabletStageLayout(song: song, size: geometry.size)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            appHeader

                            if !viewModel.isConnected {
                                connectionAlertBanner
                            }

                            if let song = viewModel.currentSong {
                                if usesTwoColumnLayout(geometry.size) {
                                    HStack(alignment: .top, spacing: 10) {
                                        currentSongPanel(
                                            song,
                                            compactLandscape: isCompactLandscape(geometry.size)
                                        )
                                        .frame(maxWidth: .infinity)

                                        VStack(spacing: 10) {
                                            nextSongPanel
                                            navigationControls
                                            showInfoButtons
                                        }
                                        .frame(
                                            width: min(
                                                max(300, geometry.size.width * 0.36),
                                                410
                                            )
                                        )
                                    }
                                } else {
                                    currentSongPanel(
                                        song,
                                        compactLandscape: isCompactLandscape(geometry.size)
                                    )
                                    nextSongPanel
                                    navigationControls
                                    showInfoButtons
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
        }
        .foregroundStyle(palette.text)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func tabletStageLayout(song: Song, size: CGSize) -> some View {
        VStack(spacing: 10) {
            appHeader

            if !viewModel.isConnected {
                connectionAlertBanner
            }

            HStack(alignment: .top, spacing: 10) {
                ScrollView {
                    currentSongPanel(
                        song,
                        compactLandscape: false
                    )
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 10) {
                    nextSongPanel
                    navigationControls
                    infoButton

                    persistentSetlist
                        .frame(maxHeight: .infinity)
                }
                .frame(
                    width: min(
                        max(320, size.width * 0.36),
                        430
                    )
                )
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, horizontalPadding(for: size))
        .padding(.bottom, 12)
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

    private func currentSongPanel(
        _ song: Song,
        compactLandscape: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
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
                .padding(.top, compactLandscape ? 10 : 18)

            Text(viewModel.currentBPMLabel ?? "— BPM")
                .font(
                    .system(
                        size: compactLandscape ? 15 : 18,
                        weight: .bold
                    )
                )
                .monospacedDigit()
                .foregroundStyle(
                    viewModel.currentBPMLabel == nil
                        ? palette.muted
                        : palette.accent
                )
                .padding(.top, compactLandscape ? 5 : 8)

            if !song.sounds.isEmpty {
                Rectangle()
                    .fill(palette.line)
                    .frame(height: 1)
                    .padding(.vertical, compactLandscape ? 12 : 18)

                if compactLandscape {
                    compactReferences(song.sounds)
                } else {
                    portraitReferences(song.sounds)
                }
            }

            if viewModel.hasTimeline {
                timelineView
                    .padding(.top, 18)
            }

            playbackControls(compactLandscape: compactLandscape)
                .padding(.top, compactLandscape ? 12 : 18)
        }
        .padding(compactLandscape ? 14 : 18)
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
    private func playbackControls(compactLandscape: Bool) -> some View {
        if !viewModel.isConnected {
            Text("SIN CONEXIÓN")
                .font(.system(size: 14, weight: .black))
                .tracking(0.8)
                .foregroundStyle(palette.muted)
                .frame(maxWidth: .infinity)
                .frame(minHeight: compactLandscape ? 52 : 58)
                .background(palette.surfaceSecondary)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(palette.line, lineWidth: 1)
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else if viewModel.playbackState == .playing {
            if compactLandscape {
                HStack(spacing: 8) {
                    playingIndicator(minHeight: 52)
                    stopControl(minHeight: 52)
                }
            } else {
                VStack(spacing: 8) {
                    playingIndicator(minHeight: 62)
                    stopControl(minHeight: 58)
                }
            }
        } else {
            Button {
                viewModel.fire()
            } label: {
                Text("DISPARAR")
                    .font(.system(size: 18, weight: .black))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: compactLandscape ? 56 : 70)
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

    private func playingIndicator(minHeight: CGFloat) -> some View {
        Text("REPRODUCIENDO")
            .font(.system(size: 16, weight: .black))
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .background(palette.playing)
            .foregroundStyle(Color(red: 0.03, green: 0.13, blue: 0.07))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.playing, lineWidth: 1)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }

    private func stopControl(minHeight: CGFloat) -> some View {
        Button {
            viewModel.stop()
        } label: {
            Text("STOP")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: minHeight)
                .background(palette.danger)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(palette.danger, lineWidth: 1)
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Detener canción")
    }

    private func portraitReferences(_ sounds: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REFERENCIAS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.35)
                .foregroundStyle(palette.muted)
                .padding(.bottom, 6)

            ForEach(Array(sounds.enumerated()), id: \.offset) { index, sound in
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

    private func compactReferences(_ sounds: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("REFERENCIAS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(palette.muted)

            FlowLayout(spacing: 16) {
                ForEach(Array(sounds.enumerated()), id: \.offset) { index, sound in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(palette.muted)

                        Text(sound)
                            .font(.system(size: 19, weight: .semibold))
                            .tracking(-0.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
            }
        }
    }

    private var nextSongPanel: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("SIGUIENTE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(palette.muted)

                    if let bpm = viewModel.bpmLabel(for: viewModel.nextSong) {
                        Text(bpm)
                            .font(.system(size: 9, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(palette.muted)
                    }
                }

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
        .disabled(!viewModel.isConnected || viewModel.playbackState == .playing)
        .opacity(
            viewModel.isConnected && viewModel.playbackState != .playing
                ? 1
                : 0.5
        )
    }

    private var showInfoButtons: some View {
        HStack(spacing: 8) {
            setlistButton
            infoButton
        }
    }

    private var infoButton: some View {
        Button {
            viewModel.isInfoPresented = true
        } label: {
            Label("INFO", systemImage: "chart.bar.xaxis")
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
            HStack {
                Text("SETLIST")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.muted)

                Spacer()

                Text("\(viewModel.songs.count) TEMAS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(palette.muted)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)

            Rectangle()
                .fill(palette.line)
                .frame(height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
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

                                    if let bpm = viewModel.bpmLabel(for: song) {
                                        Text(bpm)
                                            .font(.system(size: 8, weight: .semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(palette.muted)
                                    }

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
                                .frame(minHeight: 48)
                                .padding(.trailing, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.playbackState == .playing)
                            .id(song.id)
                            .overlay(alignment: .top) {
                                if song.id != viewModel.songs.first?.id {
                                    Rectangle()
                                        .fill(palette.line)
                                        .frame(height: 1)
                                        .padding(.leading, 40)
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.visible)
                .onChange(of: viewModel.currentSong?.id) { _, currentID in
                    guard let currentID else { return }
                    proxy.scrollTo(currentID, anchor: .center)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    private var connectionAlertCopy: (title: String, message: String) {
        if !viewModel.bridgeLinkReady {
            return (
                "BRIDGE DESCONECTADO",
                "Buscando conexión con la Mac."
            )
        }

        if !viewModel.dataStreamHealthy {
            return (
                "SIN DATOS",
                "No se reciben datos del Bridge. Controles bloqueados."
            )
        }

        if !viewModel.maxTransportReady {
            return (
                "ABLETON SIN RESPUESTA",
                "Revisá Max for Live y el dispositivo Z Live Remote."
            )
        }

        return (
            "CONEXIÓN NO DISPONIBLE",
            "Los controles permanecen bloqueados por seguridad."
        )
    }

    private var connectionAlertBanner: some View {
        let alert = connectionAlertCopy

        return HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.7)

                Text(alert.message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.text.opacity(0.82))
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.danger)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
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

    private func isCompactLandscape(_ size: CGSize) -> Bool {
        size.width > size.height && size.height <= 500
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


private struct FlowLayout: Layout {
    var spacing: CGFloat = 16

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            x += size.width + (x > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(
            width: maxWidth.isFinite ? maxWidth : x,
            height: y + rowHeight
        )
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

            if x > bounds.minX && x + size.width > bounds.maxX {
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
