import Foundation

protocol ServerHealthChecking {
    func isHealthy() async -> Bool
}

struct ServerHealthClient: ServerHealthChecking {
    let baseURL: URL
    let timeout: TimeInterval
    let session: URLSession

    init(baseURL: URL, timeout: TimeInterval = 2, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = session
    }

    func isHealthy() async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.timeoutInterval = timeout

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            let healthy = http.statusCode == 200
            AppLogger.server.debug("Health check status=\(http.statusCode) healthy=\(healthy)")
            return healthy
        } catch {
            AppLogger.server.error("Health check failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
