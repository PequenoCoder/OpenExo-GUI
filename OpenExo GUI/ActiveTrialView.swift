import SwiftUI

struct ActiveTrialView: View {
    @EnvironmentObject private var ble: BLEManager
    @EnvironmentObject private var logger: CSVLogger
    @Binding var navPath: NavigationPath

    @State private var showAltBlock = false   // toggle between [0-3] and [4-7]
    @State private var showPrefixSheet = false
    @State private var csvPrefixInput = ""
    @State private var showEndAlert = false
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if hSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear { ble.startChartTimer() }
        .onDisappear { ble.stopChartTimer() }
        .onChange(of: ble.rtData) { values in
            if logger.isLogging {
                logger.log(values: values, mark: ble.markCount)
            }
        }
        .alert("End Trial?", isPresented: $showEndAlert) {
            Button("End Trial", role: .destructive) { endTrial() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop motors, disconnect from the device, and save the CSV log.")
        }
        .sheet(isPresented: $showPrefixSheet) { prefixSheet }
    }

    // MARK: - iPad: Side by Side
    private var iPadLayout: some View {
        HStack(spacing: 0) {
            controlsPanel
                .frame(width: 300)
                .background(Color(.systemGray6).opacity(0.12))
            Divider().background(Color.gray.opacity(0.3))
            chartsPanel
        }
    }

    // MARK: - iPhone: Stacked
    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            compactHeader
            ScrollView {
                VStack(spacing: 0) {
                    chartsPanel
                        .frame(height: 320)
                    controlsPanel
                }
            }
        }
    }

    // MARK: - Compact Header (iPhone only)
    private var compactHeader: some View {
        HStack {
            batteryView
            Spacer()
            dataStatusBadge
            Spacer()
            pausePlayButton
            Spacer()
            Button(action: { showEndAlert = true }) {
                Label("End", systemImage: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.red))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6).opacity(0.15))
    }

    // Shows packet count so you can confirm data is flowing
    private var dataStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ble.rtPacketCount > 0 ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
                .shadow(color: ble.rtPacketCount > 0 ? .green : .orange, radius: 3)
            Text(ble.rtPacketCount > 0 ? "\(ble.rtPacketCount) pkts" : "No data")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Controls Panel
    private var controlsPanel: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Group 1: Title + iPad-only header controls
                Group {
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk.motion")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            Text("Active Trial")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        if logger.isLogging {
                            Text(logger.currentFileName)
                                .font(.caption2)
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .padding(.horizontal, 4)

                    if hSizeClass == .regular {
                        batteryView.padding(.horizontal, 4)
                        Divider().background(Color.gray.opacity(0.2))
                        pausePlayButton
                        endTrialButton
                        Divider().background(Color.gray.opacity(0.2))
                    }
                }

                // Group 2: Controller + Data sections
                Group {
                    sectionLabel("CONTROLLER")
                    ControlButton(title: "Update Controller", icon: "slider.horizontal.3") {
                        navPath.append(AppScreen.settings)
                    }
                    ControlButton(title: "Mark Trial (\(ble.markCount))", icon: "flag.fill") {
                        ble.markTrial()
                    }

                    sectionLabel("DATA")
                    ControlButton(title: showAltBlock ? "Show Main Block" : "Show Alt Block",
                                  icon: "chart.xyaxis.line") {
                        showAltBlock.toggle()
                    }
                    ControlButton(title: "Set CSV Prefix", icon: "pencil") {
                        csvPrefixInput = GUISettings.load().csvPrefix
                        showPrefixSheet = true
                    }
                    ControlButton(title: "Save & New CSV", icon: "doc.badge.plus") {
                        logger.rollover(prefix: GUISettings.load().csvPrefix)
                    }
                }

                // Group 3: Advanced section
                Group {
                    sectionLabel("ADVANCED")
                    ControlButton(title: "Bio Feedback", icon: "waveform.path.ecg") {
                        navPath.append(AppScreen.bioFeedback)
                    }
                    ControlButton(title: "Recalibrate FSRs", icon: "arrow.clockwise") {
                        ble.calibrateFSR()
                    }
                    ControlButton(title: "Send Preset FSR", icon: "dial.high.fill") {
                        ble.sendFSRThresholds(left: 0.25, right: 0.25)
                    }
                    ControlButton(title: "Recalibrate Torque", icon: "wrench.fill") {
                        ble.calibrateTorque()
                    }
                }
            }
            .padding(16)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Charts Panel
    private var chartsPanel: some View {
        let offset = showAltBlock ? 4 : 0
        let snapshot = ble.chartSnapshot
        let names = ble.parameterNames

        let ch0 = snapshot[offset]
        let ch1 = snapshot[offset + 1]
        let ch2 = snapshot[offset + 2]
        let ch3 = snapshot[offset + 3]

        let label0 = names.count > offset     ? names[offset]     : "Ch\(offset)"
        let label1 = names.count > offset + 1 ? names[offset + 1] : "Ch\(offset + 1)"
        let label2 = names.count > offset + 2 ? names[offset + 2] : "Ch\(offset + 2)"
        let label3 = names.count > offset + 3 ? names[offset + 3] : "Ch\(offset + 3)"

        return VStack(spacing: 12) {
            RealTimeChart(
                series1: ch0, series2: ch1,
                color1: .blue, color2: .red,
                label1: label0, label2: label1,
                title: "\(label0) · \(label1)"
            )
            RealTimeChart(
                series1: ch2, series2: ch3,
                color1: .green, color2: .purple,
                label1: label2, label2: label3,
                title: "\(label2) · \(label3)"
            )
        }
        .padding(12)
    }

    // MARK: - Battery View
    private var batteryView: some View {
        HStack(spacing: 6) {
            Image(systemName: batteryIcon)
                .font(.system(size: 18))
                .foregroundStyle(batteryColor)
            if let v = ble.batteryVoltage {
                Text(String(format: "%.2fV", v))
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(batteryColor)
            } else {
                Text("-- V")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
    }

    private var batteryIcon: String {
        guard let v = ble.batteryVoltage else { return "battery.0" }
        if v >= 11.5 { return "battery.100" }
        if v >= 11.0 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        guard let v = ble.batteryVoltage else { return .gray }
        return v >= 11.0 ? .green : .red
    }

    // MARK: - Pause/Play
    private var pausePlayButton: some View {
        Button(action: { ble.isPaused ? ble.motorsOn() : ble.motorsOff() }) {
            Label(ble.isPaused ? "Resume" : "Pause",
                  systemImage: ble.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.blue))
        }
    }

    // MARK: - End Trial (iPad only in sidebar)
    private var endTrialButton: some View {
        Button(action: { showEndAlert = true }) {
            Label("End Trial", systemImage: "stop.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.red))
        }
    }

    // MARK: - Prefix Sheet
    private var prefixSheet: some View {
        NavigationStack {
            Form {
                Section("CSV Filename Prefix") {
                    TextField("e.g. subject01", text: $csvPrefixInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text("Files will be named: \(csvPrefixInput)_trial_YYYYMMDD_HHMMSS.csv")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Set CSV Prefix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPrefixSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var settings = GUISettings.load()
                        let sanitized = csvPrefixInput.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
                        settings.csvPrefix = sanitized
                        settings.save()
                        logger.rollover(prefix: sanitized)
                        showPrefixSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions
    private func endTrial() {
        ble.endTrial()
        logger.stopLogging()
        navPath = NavigationPath()
    }
}

// MARK: - Control Button
struct ControlButton: View {
    let title: String
    let icon: String
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.gray.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6).opacity(0.2))
            )
        }
    }
}

// MARK: - Real-Time Chart (Canvas-based for 60fps performance)
struct RealTimeChart: View {
    let series1: [Double]
    let series2: [Double]
    let color1: Color
    let color2: Color
    let label1: String
    let label2: String
    let title: String

    private var hasData: Bool {
        let all = series1 + series2
        return all.contains { abs($0) > 0.01 }
    }

    private var yRange: (lo: Double, hi: Double) {
        let all = (series1 + series2).filter { abs($0) > 0.001 }
        guard !all.isEmpty else { return (-1, 1) }
        let lo = all.min()!
        let hi = all.max()!
        let pad = max((hi - lo) * 0.15, 1.0)
        return (lo - pad, hi + pad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.gray)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 10) {
                    legendDot(color: color1, label: label1)
                    legendDot(color: color2, label: label2)
                }
            }
            .padding(.horizontal, 4)

            ZStack {
            if !hasData {
                Text("Waiting for data…")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
            }
            Canvas { context, size in
                let (yMin, yMax) = yRange
                let ySpan = yMax - yMin
                guard ySpan > 0, size.width > 0, size.height > 0 else { return }

                func pt(_ i: Int, _ v: Double, _ count: Int) -> CGPoint {
                    let x = count > 1 ? size.width * CGFloat(i) / CGFloat(count - 1) : 0
                    let y = size.height * CGFloat(1.0 - (v - yMin) / ySpan)
                    return CGPoint(x: x, y: max(0, min(size.height, y)))
                }

                // Horizontal grid lines
                for i in 0...4 {
                    let y = size.height * CGFloat(i) / 4
                    var grid = Path()
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(grid, with: .color(.gray.opacity(0.18)), lineWidth: 0.5)
                }

                // Zero line
                if yMin < 0 && yMax > 0 {
                    let zY = size.height * CGFloat(1.0 - (0 - yMin) / ySpan)
                    var zLine = Path()
                    zLine.move(to: CGPoint(x: 0, y: zY))
                    zLine.addLine(to: CGPoint(x: size.width, y: zY))
                    context.stroke(zLine, with: .color(.gray.opacity(0.4)), lineWidth: 0.8)
                }

                // Series 1
                if series1.count > 1 {
                    var path = Path()
                    path.move(to: pt(0, series1[0], series1.count))
                    for i in 1..<series1.count {
                        path.addLine(to: pt(i, series1[i], series1.count))
                    }
                    context.stroke(path, with: .color(color1),
                                   style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                }

                // Series 2
                if series2.count > 1 {
                    var path = Path()
                    path.move(to: pt(0, series2[0], series2.count))
                    for i in 1..<series2.count {
                        path.addLine(to: pt(i, series2[i], series2.count))
                    }
                    context.stroke(path, with: .color(color2),
                                   style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                }

                // Y-axis labels (min/max)
                let topLabel = String(format: "%.1f", yMax)
                let botLabel = String(format: "%.1f", yMin)
                let font = Font.system(size: 8, design: .monospaced)
                context.draw(Text(topLabel).font(font).foregroundColor(.gray),
                             at: CGPoint(x: 4, y: 8), anchor: .leading)
                context.draw(Text(botLabel).font(font).foregroundColor(.gray),
                             at: CGPoint(x: 4, y: size.height - 4), anchor: .leading)
            }
            .background(Color(.systemGray6).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxHeight: .infinity)
            } // ZStack
        }
        .frame(maxHeight: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5))
        )
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: 3)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.gray)
                .lineLimit(1)
        }
    }
}
