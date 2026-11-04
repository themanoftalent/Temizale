import SwiftUI
import TemizCacheCore

// MARK: - Item card

/// One cache location: checkbox, icon, description, size and actions.
struct ItemCard: View {
    @EnvironmentObject private var model: AppModel
    let row: AppModel.Row
    var compact = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Toggle(isOn: Binding(get: { row.isSelected }, set: { _ in model.toggle(row.id) })) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityLabel("Include \(row.target.title) in cleaning")
            .disabled(model.cleaning != nil)

            IconBadge(symbol: row.target.kind.symbol, color: Theme.color(for: row.target.kind), size: compact ? 28 : 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.target.title)
                    .font(.body.weight(.semibold))
                if !compact {
                    Text(row.target.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let caution = row.target.caution {
                        Label(caution, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text(row.target.kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            sizeView
                .frame(minWidth: 80, alignment: .trailing)

            Menu {
                Button("Clean Now…", systemImage: "sparkles") { model.requestClean(row.target) }
                    .disabled((row.size ?? 0) == 0 || model.isBusy)
                Button("Show in Finder", systemImage: "folder") { model.reveal(row.target) }
                Button("Copy Paths", systemImage: "doc.on.doc") { model.copyPaths(row.target) }
                Divider()
                Section("Locations") {
                    ForEach(row.target.paths, id: \.self) { Text($0) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More actions")
            .accessibilityLabel("Actions for \(row.target.title)")
        }
        .card(padding: compact ? 12 : 16)
        .opacity(row.size == 0 ? 0.65 : 1)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.reveal(row.target) }
        .contextMenu {
            Button("Clean Now…") { model.requestClean(row.target) }
                .disabled((row.size ?? 0) == 0 || model.isBusy)
            Button("Show in Finder") { model.reveal(row.target) }
            Button("Copy Paths") { model.copyPaths(row.target) }
        }
    }

    @ViewBuilder
    private var sizeView: some View {
        if let size = row.size {
            if size == 0 {
                Text("Empty").foregroundStyle(.tertiary)
            } else {
                BytesText(bytes: size)
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
        } else {
            ProgressView().controlSize(.small).accessibilityLabel("Measuring")
        }
    }
}

// MARK: - Action bar

/// Bottom bar that summarises the selection and starts cleaning. During a
/// cleanup it turns into a progress bar.
struct ActionBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                if let progress = model.cleaning {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cleaning \(progress.current)…")
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        ProgressView(value: progress.fraction)
                            .progressViewStyle(.linear)
                            .animation(.easeOut, value: progress.fraction)
                    }
                    Text("\(progress.completed) of \(progress.total)")
                        .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                } else if model.isScanning {
                    ProgressView().controlSize(.small)
                    Text("Measuring \(model.scannedCount) of \(model.rows.count) locations…")
                        .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            BytesText(bytes: model.selectedBytes)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                            Text("selected").foregroundStyle(.secondary)
                        }
                        Text("\(model.selectedNonEmptyCount) location(s) with data · \(model.deletePermanently ? "deletes permanently" : "moves to Trash")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        model.requestCleanSelected()
                    } label: {
                        Label("Clean Selected", systemImage: "sparkles")
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled(model.selectedNonEmptyCount == 0 || model.isBusy)
                    .help("Clean all selected locations (⌘⌫)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.bar)
        .animation(.easeInOut(duration: 0.2), value: model.cleaning)
        .animation(.easeInOut(duration: 0.2), value: model.isScanning)
    }
}

// MARK: - Toast

struct ToastView: View {
    @EnvironmentObject private var model: AppModel
    let toast: AppModel.Toast

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title).font(.callout.weight(.semibold))
                if let detail = toast.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let action = toast.action, let title = toast.actionTitle {
                Button(title) { model.runToastAction(action) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Button {
                model.dismissToast(toast.id)
            } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .frame(maxWidth: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(color.opacity(0.35)))
        .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isStaticText)
    }

    private var icon: String {
        switch toast.style {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch toast.style {
        case .success: return .green
        case .info: return Theme.accent
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Page scaffold

/// Scrollable page with a large title, used by every detail screen.
struct Page<Content: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .accessibilityAddTraits(.isHeader)
                        if let subtitle {
                            Text(subtitle).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    trailing()
                }
                content()
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

extension Page where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
        self.content = content
    }
}
