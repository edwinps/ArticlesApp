import Foundation

struct HTTPClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let logger: AppLogger

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            return d
        }(),
        logger: AppLogger = DefaultLogger.shared
    ) {
        self.session = session
        self.decoder = decoder
        self.logger = logger
    }

    func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        logger.info("HTTP GET start url=\(url.absoluteString)")

        let start = Date()
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .notConnectedToInternet {
                logger.warning("HTTP GET offline url=\(url.absoluteString)")
                throw NetworkError.offline
            }
            logger.error(urlError, message: "HTTP GET transport error url=\(url.absoluteString)")
            throw NetworkError.transport(urlError)
        } catch {
            logger.error(error, message: "HTTP GET unknown transport error url=\(url.absoluteString)")
            throw NetworkError.transport(URLError(.unknown, userInfo: [NSUnderlyingErrorKey: error]))
        }

        let elapsed = Int(Date().timeIntervalSince(start) * 1000)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("HTTP GET non-HTTP response url=\(url.absoluteString) elapsedMs=\(elapsed)")
            throw NetworkError.nonHTTPResponse
        }

        logger.info("HTTP GET response url=\(url.absoluteString) status=\(httpResponse.statusCode) bytes=\(data.count) elapsedMs=\(elapsed)")

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("HTTP GET http error url=\(url.absoluteString) status=\(httpResponse.statusCode) bytes=\(data.count)")
            throw NetworkError.httpStatus(httpResponse.statusCode, data)
        }

        do {
            let decoded = try decoder.decode(T.self, from: data)
            logger.debug("HTTP GET decode success url=\(url.absoluteString) type=\(String(describing: T.self))")
            return decoded
        } catch {
            logger.error(error, message: "HTTP GET decode failed url=\(url.absoluteString) type=\(String(describing: T.self))")
            throw NetworkError.decoding(error)
        }
    }
}
