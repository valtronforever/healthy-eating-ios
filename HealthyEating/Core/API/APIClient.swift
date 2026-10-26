import Foundation

/// The REST client for one signed-in server (`/api/v1`). Adds the access token, refreshes it
/// once on 401 (the refresh is shared with concurrent requests, see `AuthSession`) and maps
/// every failure to `APIError`.
nonisolated struct APIClient: Sendable {
    let server: ServerAddress
    let auth: AuthSession
    var session: URLSession = .shared
    var calendar: Calendar = .current
    /// GET answers kept for offline use (ios#20); nil keeps nothing.
    var cache: ResponseCache?
    /// Told after every GET: nil when the server answered, the save time when a kept answer was
    /// shown because the server could not be reached.
    var onCacheUse: @Sendable (Date?) -> Void = { _ in }

    struct Request: Sendable {
        var method = "GET"
        var path: String
        var query: [URLQueryItem] = []
        var body: Data?
        var contentType = "application/json"
        /// Seconds; an import of a long history takes longer than an ordinary request.
        var timeout: TimeInterval = 20
    }

    /// Sends the request and returns the body of a 2xx answer (empty for 204). A GET answer is
    /// kept; when the server can't be reached the kept answer is returned instead, if there is one.
    func data(for request: Request) async throws(APIError) -> Data {
        guard request.method == "GET", let cache else { return try await fetch(request) }
        let key = ResponseCache.key(path: request.path, query: request.query)
        do {
            let data = try await fetch(request)
            cache.store(data, for: key)
            onCacheUse(nil)
            return data
        } catch .unreachable(let detail) {
            guard let kept = cache.entry(for: key) else { throw .unreachable(detail) }
            onCacheUse(kept.savedAt)
            return kept.body
        }
    }

    private func fetch(_ request: Request) async throws(APIError) -> Data {
        let token: String
        do {
            token = try await auth.accessToken()
        } catch {
            throw APIError(error)
        }
        let (status, data) = try await perform(request, token: token)
        guard status == 401 else { return try check(status, data) }
        let refreshed: String
        do {
            refreshed = try await auth.refresh(rejected: token)
        } catch {
            throw APIError(error)
        }
        let (retryStatus, retryData) = try await perform(request, token: refreshed)
        if retryStatus == 401 { throw .sessionExpired }
        return try check(retryStatus, retryData)
    }

    func send<Response: Decodable>(_ request: Request, as type: Response.Type = Response.self) async throws(APIError) -> Response {
        let data = try await data(for: request)
        do {
            return try APIClient.decoder.decode(Response.self, from: data)
        } catch {
            throw .unexpectedResponse(String(describing: error))
        }
    }

    private func perform(_ request: Request, token: String) async throws(APIError) -> (Int, Data) {
        var url = server.baseURL.appending(path: "api/v1").appending(path: request.path)
        if !request.query.isEmpty { url.append(queryItems: request.query) }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.timeoutInterval = request.timeout
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = request.body {
            urlRequest.httpBody = body
            urlRequest.setValue(request.contentType, forHTTPHeaderField: "Content-Type")
        }
        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else { throw APIError.unexpectedResponse("not HTTP") }
            return (http.statusCode, data)
        } catch let error as APIError {
            throw error
        } catch {
            throw .unreachable((error as? URLError)?.localizedDescription ?? error.localizedDescription)
        }
    }

    private func check(_ status: Int, _ data: Data) throws(APIError) -> Data {
        if (200..<300).contains(status) { return data }
        let body = try? APIClient.decoder.decode(ErrorResponseDTO.self, from: data)
        switch status {
        case 404:
            throw .notFound
        case 400, 422:
            var fields: [String: String] = [:]
            for detail in body?.details ?? [] {
                if let field = detail.field { fields[field] = detail.message }
            }
            throw .invalid(message: body?.message ?? String(localized: "Check the values and try again."), fields: fields)
        default:
            throw .server(code: body?.code ?? "\(status)", message: body?.message ?? HTTPURLResponse.localizedString(forStatusCode: status))
        }
    }

    // MARK: Coding

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = APIDate.parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 time: \(text)")
            }
            return date
        }
        return decoder
    }()

    static func json(_ fields: [String: Any?]) -> Data? {
        let object = fields.mapValues { $0 ?? NSNull() }
        return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

