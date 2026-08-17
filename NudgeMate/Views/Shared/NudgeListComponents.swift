import SwiftUI
import UIKit

private typealias L10n = NudgeMateStrings.Localizable

enum NudgeLayoutMetrics {
    static let screenHorizontalPadding: CGFloat = 20
    static let listHorizontalPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 22
    static let compactControlSize: CGFloat = 44
    static let cardHeaderIconSize: CGFloat = 44
    static let listSpacing: CGFloat = 12
    static let mainTabBarClearance: CGFloat = 86

    /// Keeps the final action clear of the floating tab bar on current iOS layouts.
    static let listBottomClearance: CGFloat = 128
}

struct NudgeScreenBackground: View {
    var body: some View {
        ColorTheme.background.ignoresSafeArea()
    }
}

struct NudgeScreenHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let subtitle: String
    let itemCount: Int
    let isSelecting: Bool
    let allSelected: Bool
    let onToggleSelectionMode: () -> Void
    let onToggleAll: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            NudgeHeaderTitleRow(title: title, itemCount: itemCount)

            if dynamicTypeSize.isAccessibilitySize {
                Text(subtitle)
                    .pretendard(.subheadline)
                    .foregroundStyle(ColorTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("screen.subtitle")

                HStack {
                    Spacer(minLength: 0)
                    NudgeHeaderActions(
                        isSelecting: isSelecting,
                        allSelected: allSelected,
                        onToggleSelectionMode: onToggleSelectionMode,
                        onToggleAll: onToggleAll,
                        onAdd: onAdd
                    )
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    Text(subtitle)
                        .pretendard(.subheadline)
                        .foregroundStyle(ColorTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("screen.subtitle")

                    Spacer(minLength: 8)

                    NudgeHeaderActions(
                        isSelecting: isSelecting,
                        allSelected: allSelected,
                        onToggleSelectionMode: onToggleSelectionMode,
                        onToggleAll: onToggleAll,
                        onAdd: onAdd
                    )
                }
            }
        }
        .padding(.horizontal, NudgeLayoutMetrics.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 15)
    }
}

private struct NudgeHeaderTitleRow: View {
    let title: String
    let itemCount: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                NudgeHeaderTitle(title: title)

                Spacer(minLength: 6)

                NudgeItemCountBadge(itemCount: itemCount)
            }

            VStack(alignment: .leading, spacing: 10) {
                NudgeHeaderTitle(title: title)

                HStack {
                    Spacer(minLength: 0)
                    NudgeItemCountBadge(itemCount: itemCount)
                }
            }
        }
    }
}

private struct NudgeHeaderTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .pretendard(.largeTitle, weight: .bold)
            .foregroundStyle(ColorTheme.primaryText)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("screen.title")
    }
}

private struct NudgeItemCountBadge: View {
    let itemCount: Int

    var body: some View {
        Text(L10n.Common.itemCount(itemCount))
            .pretendard(.caption, weight: .bold)
            .foregroundStyle(ColorTheme.primaryNudge)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(ColorTheme.brandSoft, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(ColorTheme.accentLavender.opacity(0.2), lineWidth: 1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("screen.itemCount")
    }
}

private struct NudgeHeaderActions: View {
    let isSelecting: Bool
    let allSelected: Bool
    let onToggleSelectionMode: () -> Void
    let onToggleAll: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if isSelecting {
                NudgeIconAction(
                    assetName: allSelected ? "glyph_clear_selection" : "glyph_select_all",
                    accessibilityLabel: allSelected ? L10n.Selection.deselectAll : L10n.Selection.selectAll,
                    foreground: ColorTheme.primaryNudge,
                    background: ColorTheme.brandSoft,
                    accessibilityIdentifier: "selection.toggleAll",
                    action: onToggleAll
                )
                NudgeIconAction(
                    assetName: "glyph_success",
                    accessibilityLabel: L10n.Common.done,
                    foreground: ColorTheme.cardBackground,
                    background: ColorTheme.primaryNudge,
                    accessibilityIdentifier: "selection.done",
                    action: onToggleSelectionMode
                )
            } else {
                NudgeIconAction(
                    assetName: "glyph_tab_prep",
                    accessibilityLabel: L10n.Common.select,
                    foreground: ColorTheme.primaryNudge,
                    background: ColorTheme.brandSoft,
                    accessibilityIdentifier: "selection.start",
                    action: onToggleSelectionMode
                )
                NudgeIconAction(
                    assetName: "glyph_add",
                    accessibilityLabel: L10n.Common.add,
                    foreground: ColorTheme.cardBackground,
                    background: ColorTheme.primaryNudge,
                    accessibilityIdentifier: "screen.add",
                    action: onAdd
                )
            }
        }
    }
}

struct NudgeIconAction: View {
    let assetName: String
    let accessibilityLabel: String
    let foreground: Color
    let background: Color
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NudgeAssetIcon(name: assetName, size: 20)
                .foregroundStyle(foreground)
                .frame(
                    width: NudgeLayoutMetrics.compactControlSize,
                    height: NudgeLayoutMetrics.compactControlSize
                )
                .background(background, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(foreground.opacity(0.12), lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(NudgePressableButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct NudgeMoreActionLabel: View {
    var tint: Color = ColorTheme.secondaryText

    var body: some View {
        NudgeAssetIcon(name: "glyph_more", size: 19)
            .foregroundStyle(tint)
            .frame(
                width: NudgeLayoutMetrics.compactControlSize,
                height: NudgeLayoutMetrics.compactControlSize
            )
            .background(ColorTheme.backgroundDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(tint.opacity(0.1), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct NudgePressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct NudgePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ColorTheme.cardBackground)
            .background(
                ColorTheme.primaryNudge,
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(ColorTheme.cardBackground.opacity(0.12), lineWidth: 1)
            }
            .shadow(
                color: ColorTheme.primaryNudge.opacity(configuration.isPressed ? 0.08 : 0.15),
                radius: configuration.isPressed ? 3 : 7,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
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
                .background(background, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(NudgePressableButtonStyle())
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
                NudgeAssetIcon(name: "glyph_success", size: 13)
                    .foregroundStyle(ColorTheme.cardBackground)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

struct NudgeSelectionActionBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedCount: Int
    let onDelete: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    NudgeSelectionSummary(selectedCount: selectedCount)
                    NudgeSelectionDeleteButton(
                        selectedCount: selectedCount,
                        action: onDelete
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 14) {
                    NudgeSelectionSummary(selectedCount: selectedCount)
                    Spacer(minLength: 8)
                    NudgeSelectionDeleteButton(
                        selectedCount: selectedCount,
                        action: onDelete
                    )
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(ColorTheme.elevatedBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ColorTheme.separator.opacity(0.7))
                .frame(height: 1)
        }
    }
}

private struct NudgeSelectionSummary: View {
    let selectedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.Selection.count(selectedCount))
                .pretendard(.headline, weight: .semibold)
                .foregroundStyle(ColorTheme.primaryText)
                .accessibilityIdentifier("selection.count")
            Text(L10n.Selection.dragHint)
                .pretendard(.caption)
                .foregroundStyle(ColorTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct NudgeSelectionDeleteButton: View {
    let selectedCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(L10n.Selection.deleteAction(selectedCount))
                .pretendard(.subheadline, weight: .semibold)
                .foregroundStyle(ColorTheme.cardBackground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(ColorTheme.destructive, in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: false, vertical: true)
        .disabled(selectedCount == 0)
        .opacity(selectedCount == 0 ? 0.45 : 1)
        .accessibilityIdentifier("selection.delete")
    }
}

struct NudgeCardSurface: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(NudgeLayoutMetrics.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: NudgeLayoutMetrics.cardCornerRadius, style: .continuous)
                    .fill(isSelected ? ColorTheme.selectionFill : ColorTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: NudgeLayoutMetrics.cardCornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? ColorTheme.primaryNudge.opacity(0.8) : ColorTheme.separator.opacity(0.34),
                        lineWidth: isSelected ? 1.5 : 0.8
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: ColorTheme.primaryText.opacity(isSelected ? 0.09 : 0.045),
                radius: isSelected ? 14 : 8,
                y: 3
            )
    }
}

private struct NudgeFormStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(NudgeScreenBackground())
            .tint(ColorTheme.primaryNudge)
    }
}

extension View {
    func nudgeCardSurface(isSelected: Bool = false) -> some View {
        modifier(NudgeCardSurface(isSelected: isSelected))
    }

    func nudgeFormStyle() -> some View {
        modifier(NudgeFormStyle())
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
