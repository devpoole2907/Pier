import Foundation

/// Docker emits multiplexed log frames when a container is not started with a TTY.
/// Each frame has an 8-byte header: [STREAM_TYPE, 0, 0, 0, SIZE_BE_UINT32], followed by SIZE bytes of payload.
/// We decode that into a clean string so the UI can just display lines of text.
///
/// When a container *is* started with a TTY, Docker sends the raw text and there's no header.
/// We detect this by sniffing the first byte: 0x01/0x02 = stdout/stderr frame, anything else is raw.
enum DockerLogStreamDecoder {
    nonisolated static func decode(data: Data) -> String {
        guard !data.isEmpty else { return "" }

        // Heuristic: framed streams always start with 0x00, 0x01, 0x02 (or rare 0x03).
        let firstByte = data[data.startIndex]
        if firstByte > 0x02 {
            return String(data: data, encoding: .utf8) ?? ""
        }

        var output = String()
        output.reserveCapacity(data.count)
        var index = data.startIndex
        while index + 8 <= data.endIndex {
            // Bytes 4-7: BE-encoded payload length.
            let sizeBytes = data[(index + 4)..<(index + 8)]
            let size = sizeBytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            let payloadStart = index + 8
            let payloadEnd = payloadStart + Int(size)
            guard payloadEnd <= data.endIndex else { break }
            let payload = data[payloadStart..<payloadEnd]
            if let text = String(data: payload, encoding: .utf8) {
                output.append(text)
            }
            index = payloadEnd
        }
        // If the loop didn't make progress, fall back to raw decoding.
        if output.isEmpty {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return output
    }
}
