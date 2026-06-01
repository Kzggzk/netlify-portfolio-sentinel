import Foundation

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetlifyAPIError.invalidResponse
        }
        return (data, httpResponse)
    }
}

public enum NetlifyAPIError: Error, LocalizedError, Equatable {
    case missingToken
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int, String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Missing Netlify token. Add it in the app or set NETLIFY_AUTH_TOKEN for CLI runs."
        case .invalidBaseURL:
            return "Invalid Netlify API base URL."
        case .invalidResponse:
            return "Netlify returned a non-HTTP response."
        case .httpStatus(let status, let body):
            return "Netlify API returned HTTP \(status): \(body)"
        case .decoding(let message):
            return "Could not decode Netlify response: \(message)"
        }
    }
}

public final class NetlifyAPIClient: @unchecked Sendable {
    public private(set) var lastRateLimitRemaining: Int?

    private let token: String
    private let baseURL: URL
    private let userAgent: String
    private let transport: HTTPTransport
    private let decoder: JSONDecoder

    public init(
        token: String,
        baseURL: URL = URL(string: "https://api.netlify.com/api/v1")!,
        userAgent: String = "NetlifyPortfolioSentinel/0.2.0 (macOS menu bar)",
        transport: HTTPTransport = URLSessionTransport()
    ) throws {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { throw NetlifyAPIError.missingToken }
        self.token = trimmedToken
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.transport = transport
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    public func fetchAllSites(maxPages: Int = 20, perPage: Int = 100) async throws -> [NetlifySite] {
        var sites: [NetlifySite] = []
        for page in 1...maxPages {
            let pageSites: [NetlifySite] = try await request(
                path: "sites",
                queryItems: [
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "per_page", value: "\(perPage)")
                ]
            )
            sites.append(contentsOf: pageSites)
            if pageSites.count < perPage { break }
        }
        return sites
    }

    public func fetchDeploys(siteID: String, perPage: Int = 100) async throws -> [NetlifyDeploy] {
        try await request(
            path: "sites/\(siteID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? siteID)/deploys",
            queryItems: [
                URLQueryItem(name: "per_page", value: "\(perPage)"),
                URLQueryItem(name: "page", value: "1")
            ]
        )
    }

    public func fetchFiles(siteID: String) async throws -> [NetlifyFile] {
        try await request(
            path: "sites/\(siteID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? siteID)/files"
        )
    }

    public func fetchAccount(idOrSlug: String) async throws -> NetlifyAccount {
        try await request(
            path: "accounts/\(idOrSlug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idOrSlug)"
        )
    }

    public func request<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw NetlifyAPIError.invalidBaseURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport.data(for: request)
        if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining") {
            lastRateLimitRemaining = Int(remaining)
        }

        guard (200..<300).contains(response.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NetlifyAPIError.httpStatus(response.statusCode, body)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetlifyAPIError.decoding(error.localizedDescription)
        }
    }
}
