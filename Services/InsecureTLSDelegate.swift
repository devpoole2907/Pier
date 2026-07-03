import Foundation

/// URLSessionDelegate that accepts any server certificate. Used only when a host opts in via
/// `Host.allowsInsecureTLS`. Common for self-signed local Komodo/NPM setups.
///
/// Marked `final` and `Sendable`; it has no mutable state.
final class InsecureTLSDelegate: NSObject, URLSessionDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
