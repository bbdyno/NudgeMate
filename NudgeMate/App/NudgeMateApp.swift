import SwiftData
import SwiftUI

@main
struct NudgeMateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainerResult: Result<ModelContainer, Error>
    @State private var appState: AppState

    init() {
        let state = AppState()
        modelContainerResult = Result {
            let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            let container = try PersistenceController.makeContainer(inMemory: isRunningTests)
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
                    RootView()
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
