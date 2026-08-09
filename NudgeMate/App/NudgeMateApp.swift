import SwiftData
import SwiftUI

@main
struct NudgeMateApp: App {
    private let modelContainer: ModelContainer
    @State private var appState: AppState

    init() {
        let schema = Schema([
            RecurringEvent.self,
            EventPrep.self
        ])
        let configuration = ModelConfiguration(
            "NudgeMate",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            let state = AppState()
            state.configure(modelContainer: container)

            modelContainer = container
            _appState = State(initialValue: state)
        } catch {
            fatalError("SwiftData 저장소를 만들 수 없습니다: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(appState)
                .environment(\.font, TypographyManager.font(for: .body))
        }
        .modelContainer(modelContainer)
    }
}
