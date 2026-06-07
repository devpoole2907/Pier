@preconcurrency import Foundation

struct NPMStream: Sendable, Decodable, Identifiable {
    let id: Int
    let incoming_port: Int
    let forwarding_host: String
    let forwarding_port: Int
    let tcp_forwarding: FlexibleBool?
    let udp_forwarding: FlexibleBool?
    let certificate_id: Int?
    let enabled: FlexibleBool?
    let owner: NPMUser?
}

struct NPMStreamCreate: Sendable, Encodable {
    let incoming_port: Int
    let forwarding_host: String
    let forwarding_port: Int
    let tcp_forwarding: FlexibleBool
    let udp_forwarding: FlexibleBool
    let certificate_id: Int?

    init(
        incomingPort: Int,
        forwardingHost: String,
        forwardingPort: Int,
        tcpForwarding: Bool = true,
        udpForwarding: Bool = false,
        certificateID: Int? = nil
    ) {
        self.incoming_port = incomingPort
        self.forwarding_host = forwardingHost
        self.forwarding_port = forwardingPort
        self.tcp_forwarding = FlexibleBool(value: tcpForwarding)
        self.udp_forwarding = FlexibleBool(value: udpForwarding)
        self.certificate_id = certificateID
    }
}

struct NPMStreamUpdate: Sendable, Encodable {
    let incoming_port: Int
    let forwarding_host: String
    let forwarding_port: Int
    let tcp_forwarding: FlexibleBool
    let udp_forwarding: FlexibleBool
    let certificate_id: Int?
    let enabled: FlexibleBool

    init(
        incomingPort: Int,
        forwardingHost: String,
        forwardingPort: Int,
        tcpForwarding: Bool,
        udpForwarding: Bool,
        certificateID: Int?,
        enabled: Bool
    ) {
        self.incoming_port = incomingPort
        self.forwarding_host = forwardingHost
        self.forwarding_port = forwardingPort
        self.tcp_forwarding = FlexibleBool(value: tcpForwarding)
        self.udp_forwarding = FlexibleBool(value: udpForwarding)
        self.certificate_id = certificateID
        self.enabled = FlexibleBool(value: enabled)
    }

    init(from stream: NPMStream) {
        self.incoming_port = stream.incoming_port
        self.forwarding_host = stream.forwarding_host
        self.forwarding_port = stream.forwarding_port
        self.tcp_forwarding = stream.tcp_forwarding ?? FlexibleBool(value: true)
        self.udp_forwarding = stream.udp_forwarding ?? FlexibleBool(value: false)
        self.certificate_id = stream.certificate_id
        self.enabled = stream.enabled ?? FlexibleBool(value: true)
    }
}
