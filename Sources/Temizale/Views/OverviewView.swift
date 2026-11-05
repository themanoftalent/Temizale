import SwiftUI
import TemizCacheCore

struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Page(title: "Overview", subtitle: subtitle) {
            hero
            if model.availableUpdatesCount > 0 {
                updatesBanner
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { tiles }
                VStack(spacing: 16) { tiles }
            }
            breakdown
            largest
        }
    }

    private var subtitle: String {
        if model.isScanning { return "Measuring cache folders…" }
        guard let lastScan = model.lastScan else { return "Not scanned yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last scanned \(formatter.localizedString(for: lastScan, relativeTo: Date()))"
    }

    // MARK: Hero

    private var hero: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reclaimable space")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                BytesText(bytes: model.isScanning && model.totalBytes == 0 ? nil : model.totalBytes, placeholder: "Measuring…")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(ByteText.string(model.selectedBytes)) selected across \(model.selectedNonEmptyCount) of \(model.rows.count) locations")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    model.requestCleanSelected()
                } label: {
                    Label("Clean Selected", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Theme.accentDeep)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(Color.white, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .opacity(model.selectedNonEmptyCount == 0 || model.isBusy ? 0.55 : 1)
                .disabled(model.selectedNonEmptyCount == 0 || model.isBusy)

                Button("Rescan") {
                    Task {
                        await model.refreshAll()
                        await model.checkForUpdates()
                    }
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .disabled(model.isBusy)
            }
        }
        .padding(24)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if model.isScanning {
                ProgressView(value: Double(model.scannedCount), total: Double(max(1, model.rows.count)))
                    .tint(.white)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Updates Banner

    private var updatesBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.availableUpdatesCount) Software Updates Available")
                    .font(.subheadline.weight(.semibold))
                Text("Updates are available for your installed applications and packages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Review & Update") {
                model.selection = .updates
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .controlSize(.small)
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.teal.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: Tiles

    @ViewBuilder
    private var tiles: some View {
        diskTile
        updatesTile
        uninstallerTile
        trashTile
        historyTile
    }

    private var diskTile: some View {
        HStack(spacing: 16) {
            RingGauge(fraction: model.disk?.usedFraction ?? 0,
                      color: (model.disk?.usedFraction ?? 0) > 0.9 ? Theme.trash : Theme.accent)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("Disk").font(.subheadline).foregroundStyle(.secondary)
                BytesText(bytes: model.disk?.available)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text("free of \(model.disk.map { ByteText.string($0.total) } ?? "—")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var updatesTile: some View {
        Button {
            model.selection = .updates
        } label: {
            HStack(spacing: 16) {
                IconBadge(symbol: "shippingbox.fill", color: .teal, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Updates").font(.subheadline).foregroundStyle(.secondary)
                    if model.isCheckingUpdates {
                        Text("Checking…").font(.system(.title3, design: .rounded).weight(.bold))
                        Text("Scanning sources").font(.caption).foregroundStyle(.secondary)
                    } else if model.availableUpdatesCount > 0 {
                        Text("\(model.availableUpdatesCount) available").font(.system(.title3, design: .rounded).weight(.bold))
                        Text("Apps & packages").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Up to date").font(.system(.title3, design: .rounded).weight(.bold))
                        Text("All packages fresh").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
        .accessibilityHint("Opens the Updates section")
    }

    private var uninstallerTile: some View {
        Button {
            model.selection = .uninstaller
        } label: {
            HStack(spacing: 16) {
                IconBadge(symbol: "trash.circle.fill", color: .red, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uninstaller").font(.subheadline).foregroundStyle(.secondary)
                    Text(model.installedApps.isEmpty ? "Scan apps" : "\(model.installedApps.count) apps")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("Deep remove & leftovers").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
        .accessibilityHint("Opens the Uninstaller section")
    }

    private var trashTile: some View {
        Button {
            model.selection = .trash
        } label: {
            HStack(spacing: 16) {
                IconBadge(symbol: "trash.fill", color: Theme.trash, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trash").font(.subheadline).foregroundStyle(.secondary)
                    if let trash = model.trash, trash.readable {
                        BytesText(bytes: trash.bytes)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Text("\(trash.itemCount) item(s)").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Access needed").font(.system(.title3, design: .rounded).weight(.bold))
                        Text("Open to measure or empty").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
        .accessibilityHint("Opens the Trash section")
    }

    private var historyTile: some View {
        HStack(spacing: 16) {
            IconBadge(symbol: "leaf.fill", color: .green, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("Freed so far").font(.subheadline).foregroundStyle(.secondary)
                BytesText(bytes: model.history.lifetimeBytes)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                if let last = model.history.lastRun {
                    Text("Last cleanup \(last.formatted(.relative(presentation: .named)))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No cleanups yet").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    // MARK: Breakdown

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Breakdown", subtitle: "Space used by each kind of cache")
            let total = max(1, model.totalBytes)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(model.kindsInUse, id: \.self) { kind in
                        let width = geo.size.width * CGFloat(Double(model.bytes(for: kind)) / Double(total))
                        if width > 0.5 {
                            Rectangle()
                                .fill(Theme.color(for: kind).gradient)
                                .frame(width: width)
                        }
                    }
                    if model.totalBytes == 0 {
                        Rectangle().fill(Color.primary.opacity(0.08))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(height: 18)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 10) {
                ForEach(model.kindsInUse, id: \.self) { kind in
                    Button {
                        model.selection = .category(kind)
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(Theme.color(for: kind)).frame(width: 8, height: 8)
                            Text(kind.title).font(.callout)
                            Spacer()
                            BytesText(bytes: model.bytes(for: kind))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    // MARK: Largest locations

    private var largest: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Largest Caches", subtitle: "Top locations taking up disk space")
            let top = model.rows
                .filter { ($0.size ?? 0) > 0 }
                .sorted { ($0.size ?? 0) > ($1.size ?? 0) }
                .prefix(6)

            if top.isEmpty {
                Text(model.isScanning ? "Measuring locations…" : "No caches found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(top) { row in
                        HStack(spacing: 12) {
                            IconBadge(symbol: row.target.kind.symbol, color: Theme.color(for: row.target.kind), size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.target.title).font(.callout.weight(.medium))
                                Text(row.target.summary).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            BytesText(bytes: row.size)
                                .font(.callout.monospacedDigit().weight(.semibold))
                            Toggle("", isOn: Binding(
                                get: { row.isSelected },
                                set: { _ in model.toggle(row.id) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        }
                        .padding(10)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .card()
    }
}
