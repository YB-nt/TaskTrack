import SwiftUI
import TaskflowCore

enum AppSection: Hashable {
    case dashboard
    case curriculum
    case sync
}

struct RootView: View {
    @State private var store = TaskDocumentStore()
    @State private var selection: AppSection? = .dashboard
    @State private var selectedItemId: String?
    @State private var scrollToPhaseId: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Dashboard", systemImage: "square.grid.2x2").tag(AppSection.dashboard)
                Label("Curriculum", systemImage: "list.bullet").tag(AppSection.curriculum)
                Label("Sync", systemImage: "arrow.triangle.2.circlepath").tag(AppSection.sync)
            }
            .navigationTitle("Taskflow")
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView(store: store, selectedItemId: $selectedItemId, onSelectPhase: { phaseId in
                        scrollToPhaseId = phaseId
                        selection = .curriculum
                    })
                case .curriculum:
                    CurriculumView(store: store, selectedItemId: $selectedItemId, scrollToPhaseId: $scrollToPhaseId)
                case .sync:
                    SyncView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.bg)
        }
        .sheet(item: selectedItemBinding) { item in
            StepDetailView(item: item, store: store)
                .frame(minWidth: 420, minHeight: 480)
        }
        .preferredColorScheme(.dark)
    }

    private var selectedItemBinding: Binding<TaskItem?> {
        Binding(
            get: { selectedItemId.flatMap { store.document?.item(withId: $0) } },
            set: { newValue in selectedItemId = newValue?.id }
        )
    }
}
