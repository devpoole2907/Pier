import Foundation
import Security

actor KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "com.poole.james.pier.ssh"

    func save(key: String, value: String) async throws {
        try KeychainStore.store(
            value: value,
            service: service,
            account: key,
            accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
    }

    func read(key: String) async throws -> String? {
        try KeychainStore.value(service: service, account: key)
    }

    func delete(key: String) async throws {
        try KeychainStore.delete(service: service, account: key)
    }
}
