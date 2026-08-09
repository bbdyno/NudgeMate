import EventKit
import Foundation

@MainActor
final class CalendarChangeObserver {
    private let notificationCenter: NotificationCenter
    private var continuation: AsyncStream<Void>.Continuation?
    private var debounceTask: Task<Void, Never>?
    private var token: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    deinit {
        if let token { notificationCenter.removeObserver(token) }
        debounceTask?.cancel()
    }

    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            self.continuation = continuation
            token = notificationCenter.addObserver(
                forName: .EKEventStoreChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.debounceChange() }
            }
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.stop() }
            }
        }
    }

    private func debounceChange() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.continuation?.yield()
        }
    }

    private func stop() {
        if let token { notificationCenter.removeObserver(token) }
        token = nil
        debounceTask?.cancel()
        continuation?.finish()
        continuation = nil
    }
}
