import AppKit
import SwiftUI

/// One scrolling settings page. Native grouped form, fixed width.
/// The quit button stays at the bottom-right; closing the window is not quitting.
struct SettingsView: View {
    @ObservedObject var model: PopoverModel
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RunningHintCard()
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 2)
            Form {
                Section {
                    ForEach(MetricDescriptor.offered) { metric in
                        Toggle(metric.title, isOn: metricBinding(metric.id))
                            .toggleStyle(.switch)
                    }
                } header: {
                    sectionHeader(L10n.tr(.showInMenu))
                } footer: {
                    Text(L10n.tr(.configHint))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Toggle(isOn: loginBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr(.launchAtLogin))
                            Text(loginDetail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    if model.loginState == .requiresApproval {
                        Button(L10n.tr(.systemSettings)) { LoginItem.openSettings() }
                            .buttonStyle(.link)
                    }
                } header: {
                    sectionHeader(L10n.tr(.general))
                }

                Section {
                    about
                } header: {
                    sectionHeader(L10n.tr(.about))
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                Button(L10n.tr(.quit), action: onQuit)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(PanelPalette.accent)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    private func metricBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { model.selectedIDs.contains(id) },
                set: { model.onSelection?(id, $0) })
    }

    private var loginBinding: Binding<Bool> {
        Binding(get: { model.loginState == .enabled || model.loginState == .requiresApproval },
                set: { model.onLogin?($0) })
    }

    private var loginDetail: String {
        if let error = model.loginError { return error }
        switch model.loginState {
        case .requiresApproval: return L10n.tr(.loginPending)
        case .unavailable: return L10n.tr(.loginUnavailable)
        default: return L10n.tr(.loginHint)
        }
    }

    private var about: some View {
        HStack(alignment: .center, spacing: 8) {
            AppIconGlyph(size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppIdentity.versionLabel)
                if !AppEdition.isAppStore {
                    Text(L10n.tr(.websiteEdition))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Link(L10n.tr(.privacyPolicy), destination: MenuGaugeLinks.privacy)
                Text("·")
                    .foregroundStyle(.secondary)
                Link(L10n.tr(.website), destination: MenuGaugeLinks.website)
            }
            .font(.system(size: 12))
        }
        .padding(.vertical, 2)
    }
}

private struct RunningHintCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MenuBarHintArt()
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr(.runningTitle))
                    .font(.system(size: 13, weight: .semibold))
                Text(L10n.tr(.runningDetail))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(PanelPalette.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Owns the single Settings window. Closing it tells the delegate so the
/// app can return to an accessory (menu-bar-only) activation policy.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    let model: PopoverModel
    var onQuit: (() -> Void)?
    var onClose: (() -> Void)?
    private var window: NSWindow?
    private var didCenter = false

    init(model: PopoverModel) {
        self.model = model
    }

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        if window.isMiniaturized { window.deminiaturize(nil) }
        if !didCenter {
            window.center()
            didCenter = true
        }
        window.makeKeyAndOrderFront(nil)
    }

    func orderFront() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    private func makeWindow() -> NSWindow {
        let size = Self.preferredContentSize()
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = L10n.tr(.settingsTitle)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.collectionBehavior = window.collectionBehavior.union(.moveToActiveSpace)
        window.delegate = self
        window.contentMinSize = size
        window.contentMaxSize = size
        let host = NSHostingController(rootView: SettingsView(model: model, onQuit: { [weak self] in
            self?.onQuit?()
        }))
        // The form's ideal height must not resize this fixed window.
        host.sizingOptions = .init()
        window.contentViewController = host
        window.setContentSize(size)
        return window
    }

    /// Wide enough for the grouped form (~520). Tall enough that the
    /// approved layout fits; a short display scrolls inside the form.
    static func preferredContentSize(visibleHeight: CGFloat = NSScreen.main?.visibleFrame.height ?? 800) -> NSSize {
        let height = min(760, max(520, visibleHeight - 28))
        return NSSize(width: 520, height: height)
    }
}
