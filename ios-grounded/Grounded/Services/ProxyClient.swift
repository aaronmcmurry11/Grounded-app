import Foundation

nonisolated enum ProxyError: LocalizedError {
    case notConfigured
    case authError
    case insufficientBalance
    case payloadTooLarge
    case rateLimited
    case serverError(Int)
    case clientError(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .notConfigured:       "Chat isn't available in this build yet. Please try again after the next update."
        case .authError:           "Chat is currently unavailable. Please restart the app."
        case .insufficientBalance: "Chat is temporarily unavailable. Please try again later."
        case .payloadTooLarge:     "That message is too long. Try asking something shorter."
        case .rateLimited:         "Too many questions at once. Wait a moment and try again."
        case .serverError:         "Something went wrong reaching Grounded. Please try again."
        case .clientError:         "Something went wrong reaching Grounded. Please try again."
        case .noData:              "No response came back. Please try again."
        }
    }
}

nonisolated func retryAfterSeconds(from response: HTTPURLResponse) -> Double? {
    guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }

    if let seconds = Double(value.trimmingCharacters(in: .whitespaces)) {
        return max(0, seconds)
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    if let date = formatter.date(from: value) {
        return max(0, date.timeIntervalSinceNow)
    }
    return nil
}

nonisolated func exponentialDelay(attempt: Int) -> Double {
    let base = pow(2.0, Double(attempt))
    let jitter = Double.random(in: 0...0.5)
    return base + jitter
}

/// Single shared sender for every call to the Rork toolkit proxy: max 2 retries,
/// `Retry-After` precedence, and a stable idempotency key across retries.
nonisolated func sendWithRetry(
    _ request: URLRequest,
    maxAttempts: Int = 3,
    session: URLSession = .shared
) async throws -> (Data, HTTPURLResponse) {
    var req = request
    if req.value(forHTTPHeaderField: "idempotency-key") == nil {
        req.setValue(UUID().uuidString, forHTTPHeaderField: "idempotency-key")
    }

    var lastTransportError: Error?

    for attempt in 0..<maxAttempts {
        let isLastAttempt = attempt == maxAttempts - 1

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw ProxyError.serverError(0)
            }

            switch http.statusCode {
            case 200...299:
                return (data, http)

            case 401:
                throw ProxyError.authError
            case 402:
                throw ProxyError.insufficientBalance
            case 413:
                throw ProxyError.payloadTooLarge

            case 429:
                if isLastAttempt { throw ProxyError.rateLimited }
                let wait = retryAfterSeconds(from: http) ?? exponentialDelay(attempt: attempt)
                try await Task.sleep(for: .seconds(wait))
                continue

            case 500...599:
                if isLastAttempt { throw ProxyError.serverError(http.statusCode) }
                let wait = retryAfterSeconds(from: http) ?? exponentialDelay(attempt: attempt)
                try await Task.sleep(for: .seconds(wait))
                continue

            default:
                throw ProxyError.clientError(http.statusCode)
            }
        } catch let error as ProxyError {
            throw error
        } catch {
            lastTransportError = error
            if isLastAttempt { throw error }
            try await Task.sleep(for: .seconds(exponentialDelay(attempt: attempt)))
            continue
        }
    }

    throw lastTransportError ?? ProxyError.serverError(0)
}
