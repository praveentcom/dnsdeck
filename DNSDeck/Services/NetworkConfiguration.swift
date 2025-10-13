import Foundation

enum NetworkConfiguration {
    static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpMaximumConnectionsPerHost = 4
        config.waitsForConnectivity = true

        // Add user agent
        config.httpAdditionalHeaders = [
            "User-Agent": "DNSDeck/1.0 (macOS)",
        ]

        return URLSession(configuration: config)
    }()
}
