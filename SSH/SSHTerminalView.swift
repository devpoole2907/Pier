import SwiftUI
import SwiftTerm

// MARK: - Bridge

enum SSHKeyModifier {
    case control
    case alt
}

@MainActor
final class SSHTerminalBridge {
    var onKeyboardVisibilityChange: ((Bool) -> Void)?
    var onModifierChange: ((SSHKeyModifier?) -> Void)?
    private var activeModifier: SSHKeyModifier?

    #if os(iOS)
    var terminalView: ScrollableTerminalView?
    #else
    weak var terminalView: TerminalView?
    #endif

    func receive(bytes: [UInt8]) {
        guard let tv = terminalView else { return }
        assert(Thread.isMainThread)
        tv.feed(byteArray: bytes[...])
    }

    var sendToSSH: ((Data) -> Void)?
    var onResize: ((Int, Int) -> Void)?
    var onTitleChange: ((String) -> Void)?

    func setModifier(_ modifier: SSHKeyModifier?) {
        activeModifier = activeModifier == modifier ? nil : modifier
        onModifierChange?(activeModifier)
    }

    func clearModifier() {
        guard activeModifier != nil else { return }
        activeModifier = nil
        onModifierChange?(nil)
    }

    func sendKeyboardInput(_ data: Data) {
        guard let modifier = activeModifier else {
            sendToSSH?(data)
            return
        }

        clearModifier()
        let bytes = [UInt8](data)
        switch modifier {
        case .control:
            sendToSSH?(Data(controlBytes(for: bytes)))
        case .alt:
            sendToSSH?(Data([0x1B] + bytes))
        }
    }

    func sendToolbarBytes(_ bytes: [UInt8]) {
        clearModifier()
        sendToSSH?(Data(bytes))
    }

    private func controlBytes(for bytes: [UInt8]) -> [UInt8] {
        guard bytes.count == 1 else { return bytes }
        let byte = bytes[0]
        switch byte {
        case 0x41...0x5A:
            return [byte - 0x40]
        case 0x61...0x7A:
            return [byte - 0x60]
        case 0x5B:
            return [0x1B]
        case 0x5C:
            return [0x1C]
        case 0x5D:
            return [0x1D]
        case 0x5E:
            return [0x1E]
        case 0x5F:
            return [0x1F]
        case 0x3F:
            return [0x7F]
        default:
            return bytes
        }
    }

    #if os(iOS)
    func hideKeyboard() {
        guard let terminalView, terminalView.window != nil, terminalView.isFirstResponder else { return }
        Task { @MainActor in
            guard terminalView.window != nil, terminalView.isFirstResponder else { return }
            _ = terminalView.resignFirstResponder()
        }
    }

    func scrollToBottom() {
        terminalView?.scrollToBottom()
    }
    #else
    func hideKeyboard() {}

    func scrollToBottom() {}
    #endif
}

// MARK: - iOS

#if os(iOS)

// MARK: Scrollable TerminalView subclass

/// Subclass that preserves the user's scroll position instead of snapping to
/// the bottom every time new terminal output arrives.
final class ScrollableTerminalView: TerminalView {

    /// True when the view should follow new output (user is at the bottom).
    private(set) var isPinnedToBottom = true
    private var isBufferUpdate = false
    var onKeyboardFocusChange: ((Bool) -> Void)?

    private var bottomOffsetY: CGFloat {
        let visibleHeight = bounds.height - adjustedContentInset.top - adjustedContentInset.bottom
        return max(-adjustedContentInset.top, contentSize.height - visibleHeight)
    }

    // Override contentOffset to track whether the user has scrolled up.
    override var contentOffset: CGPoint {
        get { super.contentOffset }
        set {
            if !isBufferUpdate {
                isPinnedToBottom = newValue.y >= bottomOffsetY - 4
            }
            super.contentOffset = newValue
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard isPinnedToBottom, !isDragging, !isTracking, !isDecelerating else { return }

        // Keep the latest prompt visible when keyboard or safe-area insets change.
        let bottomY = bottomOffsetY
        if abs(contentOffset.y - bottomY) > 1 {
            isBufferUpdate = true
            super.contentOffset = CGPoint(x: contentOffset.x, y: bottomY)
            isBufferUpdate = false
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            isPinnedToBottom = true
        }
    }

    override func becomeFirstResponder() -> Bool {
        let becameFirstResponder = super.becomeFirstResponder()
        if becameFirstResponder {
            Task { @MainActor [weak self] in
                self?.onKeyboardFocusChange?(true)
            }
        }
        return becameFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let resignedFirstResponder = super.resignFirstResponder()
        if resignedFirstResponder {
            Task { @MainActor [weak self] in
                self?.onKeyboardFocusChange?(false)
            }
        }
        return resignedFirstResponder
    }

    // Called by SwiftTerm whenever new lines arrive in the buffer.
    override func bufferActivated(source: Terminal) {
        if isPinnedToBottom {
            // Standard behaviour: snap to the latest output.
            isBufferUpdate = true
            super.bufferActivated(source: source)
            isBufferUpdate = false
        } else {
            // User has scrolled up — grow contentSize but keep their position.
            let savedY = contentOffset.y
            isBufferUpdate = true
            super.bufferActivated(source: source)
            isBufferUpdate = false
            super.contentOffset = CGPoint(x: 0, y: savedY)
        }
    }

    /// Scroll to the latest output and re-enable auto-follow.
    func scrollToBottom() {
        isPinnedToBottom = true
        setContentOffset(CGPoint(x: contentOffset.x, y: bottomOffsetY), animated: true)
    }
}

// MARK: UIViewRepresentable

final class TerminalHostingView: UIView {
    func embed(_ terminalView: UIView) {
        if terminalView.superview !== self {
            terminalView.removeFromSuperview()
            addSubview(terminalView)
            terminalView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                terminalView.leadingAnchor.constraint(equalTo: leadingAnchor),
                terminalView.trailingAnchor.constraint(equalTo: trailingAnchor),
                terminalView.topAnchor.constraint(equalTo: topAnchor),
                terminalView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }
}

struct SwiftTermView: UIViewRepresentable {
    let bridge: SSHTerminalBridge
    let wantsKeyboard: Bool
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> TerminalHostingView {
        let hostingView = TerminalHostingView()
        let terminalView = bridge.terminalView ?? ScrollableTerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        terminalView.bounces = false
        terminalView.alwaysBounceVertical = false
        terminalView.inputAccessoryView = SSHKeyboardBar(bridge: bridge)
        terminalView.onKeyboardFocusChange = { [weak bridge] isFocused in
            bridge?.onKeyboardVisibilityChange?(isFocused)
        }
        applyAppearance(to: terminalView)
        bridge.terminalView = terminalView
        hostingView.embed(terminalView)
        return hostingView
    }

    func updateUIView(_ uiView: TerminalHostingView, context: Context) {
        guard let terminalView = bridge.terminalView else { return }
        uiView.embed(terminalView)
        applyAppearance(to: terminalView)

        if wantsKeyboard {
            Task { @MainActor in
                guard terminalView.window != nil, !terminalView.isFirstResponder else { return }
                _ = terminalView.becomeFirstResponder()
            }
        } else if terminalView.isFirstResponder {
            Task { @MainActor in
                guard terminalView.window != nil, terminalView.isFirstResponder else { return }
                _ = terminalView.resignFirstResponder()
            }
        }
    }

    static func dismantleUIView(_ uiView: TerminalHostingView, coordinator: Coordinator) {
        coordinator.bridge.clearModifier()
        coordinator.bridge.onModifierChange = nil
        coordinator.bridge.terminalView?.onKeyboardFocusChange = nil
        coordinator.bridge.terminalView?.terminalDelegate = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator(bridge: bridge) }

    private func applyAppearance(to terminalView: ScrollableTerminalView) {
        let backgroundColor = UIColor.clear
        let foregroundColor: UIColor = colorScheme == .dark ? .white : .black

        terminalView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        terminalView.keyboardAppearance = colorScheme == .dark ? .dark : .light
        terminalView.backgroundColor = backgroundColor
        terminalView.layer.backgroundColor = UIColor.clear.cgColor
        terminalView.nativeBackgroundColor = backgroundColor
        terminalView.nativeForegroundColor = foregroundColor
        terminalView.caretColor = colorScheme == .dark ? .systemGreen : UIColor(red: 0.10, green: 0.48, blue: 0.24, alpha: 1)
    }

    final class Coordinator: TerminalViewDelegate {
        let bridge: SSHTerminalBridge
        init(bridge: SSHTerminalBridge) { self.bridge = bridge }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            bridge.sendKeyboardInput(Data(data))
        }
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            bridge.onResize?(newCols, newRows)
        }
        func setTerminalTitle(source: TerminalView, title: String) {
            Task { @MainActor in self.bridge.onTitleChange?(title) }
        }
        func scrolled(source: TerminalView, position: Double) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
        func bell(source: TerminalView) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        func clipboardCopy(source: TerminalView, content: Data) {
            UIPasteboard.general.string = String(decoding: content, as: UTF8.self)
        }
    }
}

// MARK: - Keyboard toolbar

private final class SSHKeyboardBar: UIInputView {
    private static let barHeight: CGFloat  = 70
    private static let keyHeight: CGFloat  = 36
    private static let keyFont    = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
    private static let barColor   = UIColor.clear
    private static let chromeColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 0.94)
            : UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 0.96)
    }
    private static let keyColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.24, alpha: 1)
            : UIColor(white: 1.0, alpha: 0.98)
    }
    private static let pressedKeyColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.36, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
    }
    private static let dividerColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.28, alpha: 1)
            : UIColor(white: 0.78, alpha: 1)
    }
    private static let keyForegroundColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .label
    }
    private static let dismissColor = UIColor.white
    private static let dismissBackgroundColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.08)
            : UIColor(white: 0.32, alpha: 0.78)
    }
    private static let horizontalInset: CGFloat = 10

    /// Terminal key identifiers resolved at press time based on terminal mode.
    private enum TerminalKey {
        case up, down, left, right
        case home, end
        case pageUp, pageDown
        case insert, delete
        case function(Int)

        var normalBytes: [UInt8] {
            switch self {
            case .up:    return [0x1B, 0x5B, 0x41]
            case .down:  return [0x1B, 0x5B, 0x42]
            case .left:  return [0x1B, 0x5B, 0x44]
            case .right: return [0x1B, 0x5B, 0x43]
            case .home: return [0x1B, 0x5B, 0x48]
            case .end: return [0x1B, 0x5B, 0x46]
            case .pageUp: return [0x1B, 0x5B, 0x35, 0x7E]
            case .pageDown: return [0x1B, 0x5B, 0x36, 0x7E]
            case .insert: return [0x1B, 0x5B, 0x32, 0x7E]
            case .delete: return [0x1B, 0x5B, 0x33, 0x7E]
            case .function(let number): return Self.functionBytes(number)
            }
        }

        var appBytes: [UInt8] {
            switch self {
            case .up:    return [0x1B, 0x4F, 0x41]
            case .down:  return [0x1B, 0x4F, 0x42]
            case .left:  return [0x1B, 0x4F, 0x44]
            case .right: return [0x1B, 0x4F, 0x43]
            case .home: return [0x1B, 0x4F, 0x48]
            case .end: return [0x1B, 0x4F, 0x46]
            case .pageUp, .pageDown, .insert, .delete, .function:
                return normalBytes
            }
        }

        private static func functionBytes(_ number: Int) -> [UInt8] {
            switch number {
            case 1: return [0x1B, 0x4F, 0x50]
            case 2: return [0x1B, 0x4F, 0x51]
            case 3: return [0x1B, 0x4F, 0x52]
            case 4: return [0x1B, 0x4F, 0x53]
            case 5: return [0x1B, 0x5B, 0x31, 0x35, 0x7E]
            case 6: return [0x1B, 0x5B, 0x31, 0x37, 0x7E]
            case 7: return [0x1B, 0x5B, 0x31, 0x38, 0x7E]
            case 8: return [0x1B, 0x5B, 0x31, 0x39, 0x7E]
            case 9: return [0x1B, 0x5B, 0x32, 0x30, 0x7E]
            case 10: return [0x1B, 0x5B, 0x32, 0x31, 0x7E]
            case 11: return [0x1B, 0x5B, 0x32, 0x33, 0x7E]
            case 12: return [0x1B, 0x5B, 0x32, 0x34, 0x7E]
            default: return []
            }
        }
    }

    private enum KeyAction {
        case bytes([UInt8])
        case terminal(TerminalKey)
        case modifier(SSHKeyModifier)
        case paste
        case scrollBottom
    }

    private struct KeyDef {
        let label: String
        let action: KeyAction

        static func fixed(_ label: String, _ bytes: [UInt8]) -> KeyDef {
            KeyDef(label: label, action: .bytes(bytes))
        }
        static func terminal(_ label: String, _ key: TerminalKey) -> KeyDef {
            KeyDef(label: label, action: .terminal(key))
        }
        static func modifier(_ label: String, _ modifier: SSHKeyModifier) -> KeyDef {
            KeyDef(label: label, action: .modifier(modifier))
        }
        static func command(_ label: String, _ action: KeyAction) -> KeyDef {
            KeyDef(label: label, action: action)
        }
    }

    private static let keys: [KeyDef] = [
        .command("Paste", .paste),
        .command("Bottom", .scrollBottom),
        .modifier("Ctrl", .control),
        .modifier("Alt", .alt),
        .fixed("Esc",  [0x1B]),
        .fixed("Tab",  [0x09]),
        .terminal("↑", .up),
        .terminal("↓", .down),
        .terminal("←", .left),
        .terminal("→", .right),
        .terminal("Home", .home),
        .terminal("End", .end),
        .terminal("PgUp", .pageUp),
        .terminal("PgDn", .pageDown),
        .terminal("Ins", .insert),
        .terminal("Del", .delete),
        .fixed("^C",   [0x03]),
        .fixed("^D",   [0x04]),
        .fixed("^W",   [0x17]),
        .fixed("^Z",   [0x1A]),
        .fixed("^A",   [0x01]),
        .fixed("^E",   [0x05]),
        .fixed("^L",   [0x0C]),
        .fixed("|",    [0x7C]),
        .fixed("/",    [0x2F]),
        .fixed("\\",   [0x5C]),
        .fixed("~",    [0x7E]),
        .fixed("-",    [0x2D]),
        .fixed("_",    [0x5F]),
        .fixed("[",    [0x5B]),
        .fixed("]",    [0x5D]),
        .fixed("{",    [0x7B]),
        .fixed("}",    [0x7D]),
        .terminal("F1", .function(1)),
        .terminal("F2", .function(2)),
        .terminal("F3", .function(3)),
        .terminal("F4", .function(4)),
        .terminal("F5", .function(5)),
        .terminal("F6", .function(6)),
        .terminal("F7", .function(7)),
        .terminal("F8", .function(8)),
        .terminal("F9", .function(9)),
        .terminal("F10", .function(10)),
        .terminal("F11", .function(11)),
        .terminal("F12", .function(12)),
    ]

    private weak var bridge: SSHTerminalBridge?
    private var activeModifier: SSHKeyModifier?
    private var keyedButtons: [(UIButton, KeyDef)] = []

    init(bridge: SSHTerminalBridge) {
        self.bridge = bridge
        super.init(
            frame: CGRect(x: 0, y: 0, width: 0, height: SSHKeyboardBar.barHeight),
            inputViewStyle: .keyboard
        )
        autoresizingMask = .flexibleWidth
        allowsSelfSizing = true
        backgroundColor = SSHKeyboardBar.barColor
        setupContent()
        bridge.onModifierChange = { [weak self] modifier in
            self?.activeModifier = modifier
            self?.refreshKeyAppearance()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Layout

    private func setupContent() {
        let chrome = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        chrome.backgroundColor = SSHKeyboardBar.chromeColor
        chrome.layer.cornerRadius = 24
        chrome.layer.cornerCurve = .continuous
        chrome.clipsToBounds = true
        chrome.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chrome)

        // Dismiss button — fixed on the right
        let dismiss = makeDismissButton()
        dismiss.translatesAutoresizingMaskIntoConstraints = false
        chrome.contentView.addSubview(dismiss)

        // Vertical divider between scroll area and dismiss button
        let divider = UIView()
        divider.backgroundColor = SSHKeyboardBar.dividerColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        chrome.contentView.addSubview(divider)

        // Scrollable key area on the left
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.alwaysBounceVertical = false
        scroll.bounces = true
        scroll.isDirectionalLockEnabled = true
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 10)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        chrome.contentView.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 7
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        for keyDef in SSHKeyboardBar.keys {
            let button = makeKey(keyDef)
            keyedButtons.append((button, keyDef))
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SSHKeyboardBar.horizontalInset),
            chrome.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SSHKeyboardBar.horizontalInset),
            chrome.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            chrome.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8),

            // Dismiss button
            dismiss.trailingAnchor.constraint(equalTo: chrome.contentView.trailingAnchor, constant: -8),
            dismiss.centerYAnchor.constraint(equalTo: chrome.contentView.centerYAnchor),
            dismiss.widthAnchor.constraint(equalToConstant: 38),
            dismiss.heightAnchor.constraint(equalToConstant: SSHKeyboardBar.keyHeight),

            // Divider
            divider.trailingAnchor.constraint(equalTo: dismiss.leadingAnchor, constant: -6),
            divider.centerYAnchor.constraint(equalTo: chrome.contentView.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 0.5),
            divider.heightAnchor.constraint(equalToConstant: 24),

            // Scroll view
            scroll.leadingAnchor.constraint(equalTo: chrome.contentView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: divider.leadingAnchor, constant: -2),
            scroll.topAnchor.constraint(equalTo: chrome.contentView.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: chrome.contentView.bottomAnchor),

            // Key stack inside scroll view
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }

    // MARK: Key buttons

    private func makeKey(_ keyDef: KeyDef) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = keyDef.label
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = SSHKeyboardBar.keyFont; return a
        }
        cfg.baseBackgroundColor = SSHKeyboardBar.keyColor
        cfg.baseForegroundColor = SSHKeyboardBar.keyForegroundColor
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 11, bottom: 0, trailing: 11)
        cfg.background.cornerRadius = 8

        let btn = UIButton(configuration: cfg)
        btn.heightAnchor.constraint(equalToConstant: SSHKeyboardBar.keyHeight).isActive = true
        btn.widthAnchor.constraint(equalToConstant: width(for: keyDef)).isActive = true
        btn.configurationUpdateHandler = { [weak self] b in
            var c = b.configuration!
            let isActiveModifier = self?.isActiveModifier(keyDef) ?? false
            c.baseBackgroundColor = isActiveModifier || b.isHighlighted ? SSHKeyboardBar.pressedKeyColor : SSHKeyboardBar.keyColor
            c.baseForegroundColor = SSHKeyboardBar.keyForegroundColor
            b.configuration = c
        }
        btn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.perform(keyDef)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }, for: .touchUpInside)
        return btn
    }

    private func perform(_ keyDef: KeyDef) {
        switch keyDef.action {
        case .modifier(let modifier):
            bridge?.setModifier(modifier)

        case .paste:
            bridge?.clearModifier()
            bridge?.terminalView?.paste(nil)

        case .scrollBottom:
            bridge?.scrollToBottom()
            bridge?.clearModifier()

        case .bytes(let bytes):
            send(bytes)

        case .terminal(let key):
            let appCursor = bridge?.terminalView?.getTerminal().applicationCursor ?? false
            send(appCursor ? key.appBytes : key.normalBytes)
        }
    }

    private func send(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        bridge?.sendToolbarBytes(bytes)
    }

    private func isActiveModifier(_ keyDef: KeyDef) -> Bool {
        guard case .modifier(let modifier) = keyDef.action else { return false }
        return modifier == activeModifier
    }

    private func refreshKeyAppearance() {
        for button in keyedButtons.map(\.0) {
            button.setNeedsUpdateConfiguration()
        }
    }

    private func width(for keyDef: KeyDef) -> CGFloat {
        keyDef.label.count <= 2 ? 36 : 72
    }

    private func makeDismissButton() -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: "keyboard.chevron.compact.down",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        cfg.baseForegroundColor = SSHKeyboardBar.dismissColor
        cfg.contentInsets = .zero

        let btn = UIButton(configuration: cfg)
        btn.configurationUpdateHandler = { b in
            var c = b.configuration!
            c.baseForegroundColor = b.isHighlighted ? SSHKeyboardBar.keyForegroundColor : SSHKeyboardBar.dismissColor
            b.configuration = c
        }
        btn.backgroundColor = SSHKeyboardBar.dismissBackgroundColor
        btn.layer.cornerRadius = SSHKeyboardBar.keyHeight / 2
        btn.layer.cornerCurve = .continuous
        btn.addAction(UIAction { [weak self] _ in
            self?.bridge?.hideKeyboard()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }, for: .touchUpInside)
        return btn
    }
}

#endif

// MARK: - macOS

#if os(macOS)
struct SwiftTermView: NSViewRepresentable {
    let bridge: SSHTerminalBridge
    let wantsKeyboard: Bool
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> TerminalView {
        let tv = TerminalView(frame: .zero)
        tv.terminalDelegate = context.coordinator
        bridge.terminalView = tv
        return tv
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        guard let window = nsView.window else { return }

        if wantsKeyboard {
            if window.firstResponder !== nsView {
                window.makeFirstResponder(nsView)
            }
        } else if window.firstResponder === nsView {
            window.makeFirstResponder(nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(bridge: bridge) }

    final class Coordinator: TerminalViewDelegate {
        private let bridge: SSHTerminalBridge
        init(bridge: SSHTerminalBridge) { self.bridge = bridge }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            bridge.sendToSSH?(Data(data))
        }
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            bridge.onResize?(newCols, newRows)
        }
        func setTerminalTitle(source: TerminalView, title: String) {
            Task { @MainActor in self.bridge.onTitleChange?(title) }
        }
        func scrolled(source: TerminalView, position: Double) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(decoding: content, as: UTF8.self), forType: .string)
        }
    }
}
#endif
