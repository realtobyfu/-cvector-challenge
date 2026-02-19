import Foundation
@testable import grove

/// Mock URL metadata fetcher for testing. Returns canned metadata or nil.
final class MockURLMetadataFetcher: URLMetadataFetcherProtocol, @unchecked Sendable {
    var result: URLMetadata?
    var fetchedURLs: [String] = []

    func fetch(urlString: String) async -> URLMetadata? {
        fetchedURLs.append(urlString)
        return result
    }
}
