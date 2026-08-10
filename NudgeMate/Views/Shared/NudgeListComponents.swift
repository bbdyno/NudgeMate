import SwiftUI
import UIKit

private typealias L10n = NudgeMateStrings.Localizable

enum NudgeLayoutMetrics {
    /// Keeps the final action clear of the floating tab bar on current iOS layouts.
    static let listBottomClearance: CGFloat = 116
}

struct NudgeScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [ColorTheme.background, ColorTheme.backgroundDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct NudgeScreenHeader: View {
    let title: String
    let subtitle: String
    let itemCount: Int
    let isSelecting: Bool
    let allSelected: Bool
    let onToggleSelectionMode: () -> Void
    let onToggleAll: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .pretendard(.largeTitle, weight: .bold)
                        .foregroundStyle(ColorTheme.primaryText)
                    Text(subtitle)
                        .pretendard(.subheadline)
                        .foregroundStyle(ColorTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(L10n.Common.itemCount(itemCount))
                    .pretendard(.caption, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryNudge)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 31)
                    .background(ColorTheme.brandSoft, in: Capsule())
                    .accessibilityIdentifier("screen.itemCount")
            }

            HStack(spacing: 8) {
                Spacer()
                if isSelecting {
                    NudgeTextAction(
                        title: allSelected ? L10n.Selection.deselectAll : L10n.Selection.selectAll,
                        foreground: ColorTheme.primaryNudge,
                        background: ColorTheme.brandSoft,
                        accessibilityIdentifier: "selection.toggleAll",
                        action: onToggleAll
                    )
                    NudgeTextAction(
                        title: L10n.Common.done,
                        foreground: ColorTheme.cardBackground,
                        background: ColorTheme.primaryNudge,
                        accessibilityIdentifier: "selection.done",
                        action: onToggleSelectionMode
                    )
                } else {
                    NudgeTextAction(
                        title: L10n.Common.select,
                        foreground: ColorTheme.primaryNudge,
                        background: ColorTheme.brandSoft,
                        accessibilityIdentifier: "selection.start",
                        action: onToggleSelectionMode
                    )
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(ColorTheme.cardBackground)
                            .frame(width: 44, height: 44)
                            .background(ColorTheme.primaryNudge, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Common.add)
                    .accessibilityIdentifier("screen.add")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }
}

struct NudgeTextAction: View {
    let title: String
    let foreground: Color
    let background: Color
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .pretendard(.caption, weight: .semibold)
                .foregroundStyle(foreground)
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .background(background, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct NudgeSelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? ColorTheme.primaryNudge : ColorTheme.cardBackground)
            Circle()
                .stroke(
                    isSelected ? ColorTheme.primaryNudge : ColorTheme.separator,
                    lineWidth: 1.5
                )
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ColorTheme.cardBackground)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

struct NudgeSelectionActionBar: View {
    let selectedCount: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Selection.count(selectedCount))
                    .pretendard(.headline, weight: .semibold)
                    .foregroundStyle(ColorTheme.primaryText)
                    .accessibilityIdentifier("selection.count")
                Text(L10n.Selection.dragHint)
                    .pretendard(.caption)
                    .foregroundStyle(ColorTheme.secondaryText)
            }
            Spacer()
            Button(action: onDelete) {
                Text(L10n.Selection.deleteAction(selectedCount))
                    .pretendard(.subheadline, weight: .semibold)
                    .foregroundStyle(ColorTheme.cardBackground)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(ColorTheme.destructive, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.45 : 1)
            .accessibilityIdentifier("selection.delete")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(ColorTheme.elevatedBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ColorTheme.separator.opacity(0.7))
                .frame(height: 1)
        }
    }
}

struct NudgeCardSurface: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                isSelected ? ColorTheme.selectionFill : ColorTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isSelected ? ColorTheme.primaryNudge.opacity(0.8) : ColorTheme.separator.opacity(0.45),
                        lineWidth: isSelected ? 1.5 : 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: ColorTheme.primaryText.opacity(isSelected ? 0.09 : 0.055),
                radius: isSelected ? 14 : 9,
                y: 4
            )
    }
}

extension View {
    func nudgeCardSurface(isSelected: Bool = false) -> some View {
        modifier(NudgeCardSurface(isSelected: isSelected))
    }

    func nudgeSelectionFrame(id: UUID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: NudgeSelectionFrameKey.self,
                    value: [id: proxy.frame(in: .global)]
                )
            }
        }
    }
}

struct NudgeSelectionFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

struct NudgeSelectionGeometry {
    static func itemID(at location: CGPoint, itemFrames: [UUID: CGRect]) -> UUID? {
        itemFrames
            .filter { $0.value.insetBy(dx: -6, dy: -6).contains(location) }
            .min { $0.value.minY < $1.value.minY }?
            .key
    }

    static func itemIDs(
        between start: CGPoint,
        and end: CGPoint,
        itemFrames: [UUID: CGRect]
    ) -> [UUID] {
        let selectionPath = CGRect(
            x: min(start.x, end.x) - 10,
            y: min(start.y, end.y) - 10,
            width: abs(start.x - end.x) + 20,
            height: abs(start.y - end.y) + 20
        )
        return itemFrames
            .filter { $0.value.intersects(selectionPath) }
            .sorted { $0.value.minY < $1.value.minY }
            .map(\.key)
    }
}

struct TwoFingerSelectionInstaller: UIViewRepresentable {
    let itemFrames: [UUID: CGRect]
    let selectedIDs: Set<UUID>
    let onSelectionStarted: () -> Void
    let onSelectionChanged: (UUID, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WindowTrackingView {
        let view = WindowTrackingView()
        view.isUserInteractionEnabled = false
        view.onWindowChanged = { window in
            context.coordinator.install(on: window)
        }
        return view
    }

    func updateUIView(_ uiView: WindowTrackingView, context: Context) {
        context.coordinator.itemFrames = itemFrames
        context.coordinator.selectedIDs = selectedIDs
        context.coordinator.onSelectionStarted = onSelectionStarted
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.install(on: uiView.window)
    }

    static func dismantleUIView(_ uiView: WindowTrackingView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var itemFrames: [UUID: CGRect] = [:]
        var selectedIDs: Set<UUID> = []
        var onSelectionStarted: () -> Void = {}
        var onSelectionChanged: (UUID, Bool) -> Void = { _, _ in }

        private weak var installedWindow: UIWindow?
        private var visitedIDs: Set<UUID> = []
        private var targetSelectionState = true
        private var previousLocation: CGPoint?
        private lazy var gesture: UIPanGestureRecognizer = {
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            gesture.minimumNumberOfTouches = 2
            gesture.maximumNumberOfTouches = 2
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            return gesture
        }()

        func install(on window: UIWindow?) {
            guard installedWindow !== window else { return }
            uninstall()
            guard let window else { return }
            window.addGestureRecognizer(gesture)
            installedWindow = window
        }

        func uninstall() {
            installedWindow?.removeGestureRecognizer(gesture)
            installedWindow = nil
            visitedIDs.removeAll()
            previousLocation = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let view = gestureRecognizer.view else { return false }
            return NudgeSelectionGeometry.itemID(
                at: gestureRecognizer.location(in: view),
                itemFrames: itemFrames
            ) != nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)

            switch gesture.state {
            case .began:
                guard let id = NudgeSelectionGeometry.itemID(
                    at: location,
                    itemFrames: itemFrames
                ) else { return }
                visitedIDs = [id]
                previousLocation = location
                targetSelectionState = !selectedIDs.contains(id)
                onSelectionStarted()
                onSelectionChanged(id, targetSelectionState)
            case .changed:
                let ids = NudgeSelectionGeometry.itemIDs(
                    between: previousLocation ?? location,
                    and: location,
                    itemFrames: itemFrames
                )
                for id in ids where !visitedIDs.contains(id) {
                    visitedIDs.insert(id)
                    onSelectionChanged(id, targetSelectionState)
                }
                previousLocation = location
            case .ended, .cancelled, .failed:
                visitedIDs.removeAll()
                previousLocation = nil
            default:
                break
            }
        }

    }
}

final class WindowTrackingView: UIView {
    var onWindowChanged: (UIWindow?) -> Void = { _ in }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChanged(window)
    }
}
