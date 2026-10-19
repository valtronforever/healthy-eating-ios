import Foundation

/// The REST client for one signed-in server (`/api/v1`). Adds the access token, refreshes it
/// once on 401 (the refresh is shared with concurrent requests, see `AuthSession`) and maps
/// every failure to `APIError`.
nonisolated struct APIClient: Sendable {
    let server: ServerAddress
    let auth: AuthSession
    var session: URLSession = .shared
    var calendar: Calendar = .current

    struct Request: Sendable {
        var method = "GET"
        var path: String
        var query: [URLQueryItem] = []
        var body: Data?
    }

    /// Sends the request and returns the body of a 2xx answer (empty for 204).
    func data(for request: Request) async throws(APIError) -> Data {
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
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = request.body {
            urlRequest.httpBody = body
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

/// Times and local days as the backend writes them.
nonisolated enum APIDate {
    /// ISO 8601 with a UTC offset, with or without fractional seconds (Python writes up to six
    /// digits; Foundation reads three).
    static func parse(_ text: String) -> Date? {
        var value = text
        if let dot = value.firstIndex(of: "."),
           let end = value[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let digits = value[value.index(after: dot)..<end]
            value.replaceSubrange(dot..<end, with: "." + String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0))
            return try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        }
        return try? Date(value, strategy: .iso8601)
    }

    /// A local day ("2026-10-18") as midnight in the device calendar.
    static func day(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// A date's local day for the API ("2026-10-18").
    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// A time with the device's offset, for `eaten_at` in meal edits.
    static func timeString(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: timeZone))
    }
}
