import Foundation

extension Int64 {
    /// Renders bytes as a human readable string using Apple's preferred units, e.g. "1.4 GB".
    var byteCountString: String {
        ByteCountFormatStyle().format(self)
    }
}

extension ByteCountFormatStyle {
    init() {
        self.init(style: .file, allowedUnits: .all, spellsOutZero: false, includesActualByteCount: false)
    }
}
