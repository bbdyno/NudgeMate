import SwiftData
import SwiftUI

@main
struct NudgeMateApp: App {
    private let modelContainerResult: Result<ModelContainer, Error>
    @State private var appState: AppState

    init() {
        let state = AppState()
        modelContainerResult = Result {
            let container = try PersistenceController.makeContainer()
            state.configure(modelContainer: container)
            return container
        }
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch modelContainerResult {
                case let .success(modelContainer):
                    HomeView()
                        .modelContainer(modelContainer)
                case .failure:
                    EmptyStateView(
                        icon: .emptyState,
                        title: NudgeMateStrings.Localizable.App.Storage.title,
                        message: NudgeMateStrings.Localizable.App.Storage.message
                    )
                }
            }
            .environment(appState)
            .environment(\.font, TypographyManager.font(for: .body))
        }
    }
}
