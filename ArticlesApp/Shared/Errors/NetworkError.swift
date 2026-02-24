//
//  NetworkError.swift
//  ArticlesApp
//
//

import Foundation

enum NetworkError: Error, Sendable, LocalizedError, Equatable {
    case invalidURL
    case transport(URLError)
    case nonHTTPResponse
    case httpStatus(Int, Data?)
    case decoding(Error)
    case offline
    
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.offline, .offline):
            return true
        case (.nonHTTPResponse, .nonHTTPResponse):
            return true
            
        case (.httpStatus(let a, _), .httpStatus(let b, _)):
            return a == b  
            
        case (.transport(let a), .transport(let b)):
            return a.code == b.code
            
        case (.decoding, .decoding):
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The requested URL is invalid."
        case .offline:
            return "You appear to be offline. Please check your internet connection."
        case .transport(let urlError):
            switch urlError.code {
            case .timedOut:
                return "The request timed out. Please try again."
            case .cannotFindHost:
                return "Cannot find the server. Please check the URL or your connection."
            case .cannotConnectToHost:
                return "Cannot connect to the server. Please try again later."
            case .networkConnectionLost:
                return "The network connection was lost. Please try again."
            case .secureConnectionFailed:
                return "A secure connection could not be established."
            default:
                return urlError.localizedDescription
            }
        case .nonHTTPResponse:
            return "The server returned an unexpected response."
        case .httpStatus(let status, _):
            return "The server responded with an error (code \(status))."
        case .decoding:
            return "We couldn't read the data from the server."
        }
    }
}
