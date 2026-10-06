import SwiftUI
import Charts

struct InfoView: View {
    @ObservedObject var viewModel: LiveRemoteViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private let cornerRadius: CGFloat = 4

    private var palette: AppPalette {
        AppPalette(theme: themeManager.theme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    overviewGrid
                    energySection
                    durationNote
                }
                .padding(14)
            }
            .background(palette.background)
            .navigationTitle("INFO DEL SHOW")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(palette.surface)
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: cornerRadius,
                                    style: .continuous
                                )
                                .stroke(palette.line, lineWidth: 1)
                            }
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: cornerRadius,
                                    style: .continuous
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar información")
                }
            }
        }
        .foregroundStyle(palette.text)
    }

    private var overviewGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            metricCard(
                title: "TEMAS",
                value: "\(viewModel.songs.count)"
            )

            metricCard(
                title: "DURACIÓN MUSICAL",
                value: durationSummary
            )

            metricCard(
                title: "BPM PROMEDIO",
                value: bpmSummary(viewModel.averageBPM)
            )

            metricCard(
                title: "RANGO BPM",
                value: bpmRangeSummary
            )
        }
    }

    private var energySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ENERGÍA DEL SHOW")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(palette.muted)

                Text("Curva estimada a partir de los BPM de cada canción")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.muted)
            }

            if energyPoints.isEmpty {
                Text("Esperando información de BPM.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 52)
            } else {
                Chart(energyPoints) { point in
                    BarMark(
                        x: .value("Tema", point.position),
                        y: .value("BPM", point.bpm)
                    )
                    .foregroundStyle(
                        viewModel.currentSong?.id == point.song.id
                            ? palette.playing
                            : palette.accent
                    )
                    .cornerRadius(2)
                }
                .chartYScale(domain: bpmDomain)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine()
                            .foregroundStyle(palette.line.opacity(0.45))
                        AxisValueLabel()
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(palette.muted)
                    }
                }
                .frame(height: 220)
                .clipped()

                HStack {
                    Text("INICIO")
                    Spacer()
                    Text("ORDEN DEL SETLIST")
                    Spacer()
                    Text("FIN")
                }
                .font(.system(size: 8, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(palette.muted)

                Rectangle()
                    .fill(palette.line)
                    .frame(height: 1)
                    .padding(.top, 4)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.top, 1)

                    Text(
                        "La curva usa BPM como referencia rítmica. No mide por sí sola la intensidad musical real."
                    )
                    .font(.system(size: 10, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(palette.muted)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(palette.surface)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    private var durationNote: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("SOBRE LA DURACIÓN")
                .font(.system(size: 10, weight: .black))
                .tracking(1.0)
                .foregroundStyle(palette.muted)

            Text(
                viewModel.hasCompleteSetlistDuration
                    ? "La duración suma el contenido musical de las Scenes. No incluye pausas, charla ni cambios entre canciones."
                    : "Duración parcial: se recibieron tiempos de \(viewModel.knownDurationSongCount) de \(viewModel.songs.count) canciones."
            )
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(palette.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceSecondary)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .tracking(0.9)
                .foregroundStyle(palette.muted)

            Text(value)
                .font(.system(size: 20, weight: .black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(12)
        .background(palette.surface)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.line, lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    private var durationSummary: String {
        let total = viewModel.totalSetlistDuration

        guard total > 0 else { return "—" }

        let rounded = Int(total.rounded())
        let hours = rounded / 3600
        let minutes = (rounded % 3600) / 60
        let seconds = rounded % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    private func bpmSummary(_ bpm: Double?) -> String {
        guard let bpm else { return "—" }

        if abs(bpm.rounded() - bpm) < 0.01 {
            return String(format: "%.0f", bpm)
        }

        return String(format: "%.1f", bpm)
    }

    private var bpmRangeSummary: String {
        guard
            let minimum = viewModel.minimumBPM,
            let maximum = viewModel.maximumBPM
        else { return "—" }

        return "\(bpmSummary(minimum))–\(bpmSummary(maximum))"
    }

    private struct EnergyPoint: Identifiable {
        let id: Int
        let position: Int
        let bpm: Double
        let song: Song
    }

    private var energyPoints: [EnergyPoint] {
        viewModel.songs.enumerated().compactMap { offset, song in
            guard let bpm = viewModel.bpm(for: song) else { return nil }

            return EnergyPoint(
                id: song.id,
                position: offset + 1,
                bpm: bpm,
                song: song
            )
        }
    }

    private var bpmDomain: ClosedRange<Double> {
        guard
            let minimum = viewModel.minimumBPM,
            let maximum = viewModel.maximumBPM
        else {
            return 60...160
        }

        let lower = max(20, floor((minimum - 10) / 10) * 10)
        let upper = max(
            lower + 20,
            ceil((maximum + 10) / 10) * 10
        )

        return lower...upper
    }
}

#Preview {
    InfoView(viewModel: LiveRemoteViewModel())
        .environmentObject(ThemeManager())
}
