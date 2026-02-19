import Foundation

/// Extract the display domain from a URL string, stripping "www." prefix.
/// Shared across InboxCard, ItemCardView, and any other view that shows source domains.
func domainFrom(_ urlString: String) -> String {
    guard let url = URL(string: urlString),
          let host = url.host else {
        return urlString
    }
    return host.replacingOccurrences(of: "www.", with: "")
}
