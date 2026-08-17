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
            let processInfo = ProcessInfo.processInfo
            let isRunningTests = processInfo.environment["XCTestConfigurationFilePath"] != nil
                || processInfo.arguments.contains("--ui-testing")
            let container = try PersistenceController.makeContainer(inMemory: isRunningTests)
#if DEBUG
            try UITestScenarioConfigurator.configureIfNeeded(modelContainer: container)
#endif
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
                        icon: .empty,
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
