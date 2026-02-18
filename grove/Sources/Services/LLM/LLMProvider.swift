import Foundation

/// Result from an LLM completion call, including token usage.
struct LLMCompletionResult: Sendable {
    let content: String
    let inputTokens: Int
    let outputTokens: Int
}

/// Protocol for LLM service providers.
/// All implementations must be async, non-blocking, and failure-tolerant.
protocol LLMProvider: Sendable {
    /// Send a chat completion request and return the response text.
    /// Returns nil on failure — never throws to callers.
    func complete(system: String, user: String) async -> LLMCompletionResult?

    /// Send a chat completion request tagged with a service name for token tracking.
    /// Returns nil on failure — never throws to callers.
    func complete(system: String, user: String, service: String) async -> LLMCompletionResult?
}

extension LLMProvider {
    func complete(system: String, user: String, service: String) async -> LLMCompletionResult? {
        await complete(system: system, user: user)
    }
}
