import SwiftUI
import TaskflowCore

struct SyncView: View {
    var store: TaskDocumentStore

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s6) {
                Text("Sync").font(DesignTokens.Typography.heading(20))

                fileCard
                if store.document != nil {
                    statsRow
                    frequencyCard
                }

                HStack(spacing: 10) {
                    Button("Sync Now") { store.sync() }
                        .buttonStyle(.taskflowPrimary)
                        .disabled(store.fileURL == nil)
                    Button("Add File") { pickFile() }
                        .buttonStyle(.taskflowSecondary)
                }

                if let error = store.lastError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Colors.accent300)
                }

                if !store.changeLog.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Changes")
                            .font(DesignTokens.Typography.heading(12))
                            .foregroundStyle(DesignTokens.Colors.neutral400)
                        VStack(spacing: 10) {
                            ForEach(store.changeLog) { entry in
                                HStack {
                                    Text(entry.text).font(.system(size: 12.5))
                                    Spacer()
                                    Text(Self.relativeFormatter.localizedString(for: entry.date, relativeTo: Date()))
                                        .font(.system(size: 12))
                                        .foregroundStyle(DesignTokens.Colors.neutral400)
                                }
                                .padding(.bottom, 8)
                                .overlay(Rectangle().fill(DesignTokens.Colors.divider).frame(height: 1), alignment: .bottom)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.s8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignTokens.Colors.bg)
        .foregroundStyle(DesignTokens.Colors.text)
    }

    private var fileCard: some View {
        CardView(elevated: true) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.Colors.accent800)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "doc.text").foregroundStyle(DesignTokens.Colors.accent200))
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.fileURL?.lastPathComponent ?? "연결된 파일 없음")
                        .font(DesignTokens.Typography.heading(14))
                    Text(store.document?.sourceLabel ?? "Sync Now 또는 Add File로 taskmaster .md를 연결하세요")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.Colors.neutral400)
                }
            }
            if let lastSynced = store.lastSyncedAt {
                Text("Synced \(Self.relativeFormatter.localizedString(for: lastSynced, relativeTo: Date()))")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.Colors.neutral400)
            }
        }
    }

    private var statsRow: some View {
        let allLeaves = store.document?.tasks.flatMap(\.leaves) ?? []
        let doneCount = allLeaves.filter { $0.status == .done }.count
        return HStack(spacing: 8) {
            statCard(String(store.document?.tasks.count ?? 0), "Phase")
            statCard(String(allLeaves.count), "Step")
            statCard(String(allLeaves.count - doneCount), "Steps Remaining")
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        CardView {
            VStack(spacing: 2) {
                Text(value).font(DesignTokens.Typography.heading(20))
                Text(label).font(.system(size: 11)).foregroundStyle(DesignTokens.Colors.neutral400)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var frequencyCard: some View {
        CardView {
            Text("Sync Frequency")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.Colors.accent)
            Picker("", selection: Binding(get: { store.syncFrequency }, set: { store.syncFrequency = $0 })) {
                ForEach(SyncFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.label).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
            Text(store.syncFrequency.detail)
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.Colors.text.opacity(0.8))
        }
    }

    private func pickFile() {
        guard let url = FilePicker.pickMarkdownFile() else { return }
        store.chooseFile(url: url)
    }
}
