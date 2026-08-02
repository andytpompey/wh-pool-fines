import Foundation

actor NetworkClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
    }

    func send<Response>(_ request: APIRequest<Response>) async throws -> Response {
        guard let url = URL(string: request.path, relativeTo: baseURL) else {
            throw RooBinError.unexpected
        }

        var urlRequest = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("no-store, no-cache", forHTTPHeaderField: "Cache-Control")
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let key = request.idempotencyKey {
            urlRequest.setValue(key.uuidString, forHTTPHeaderField: "Idempotency-Key")
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RooBinError.unexpected
            }
            try validate(httpResponse)
            return try decoder.decode(Response.self, from: data)
        } catch let error as RooBinError {
            throw error
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw RooBinError.offline
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RooBinError.unexpected
        }
    }

    private func validate(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 401:
            throw RooBinError.unauthenticated
        case 403:
            throw RooBinError.forbidden
        case 404:
            throw RooBinError.notFound
        case 409:
            throw RooBinError.conflict
        case 410:
            throw RooBinError.expired
        case 429:
            throw RooBinError.rateLimited
        case 500...599:
            throw RooBinError.serviceUnavailable
        default:
            throw RooBinError.unexpected
        }
    }
}
