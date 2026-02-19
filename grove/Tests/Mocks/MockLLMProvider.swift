import Foundation
@testable import grove

/// Mock LLM provider for testing. Returns canned responses or nil.
final class MockLLMProvider: LLMProvider, @unchecked Sendable {
    var responseContent: String?
    var completions: [(system: String, user: String, service: String)] = []

    func complete(system: String, user: String) async -> LLMCompletionResult? {
        completions.append((system, user, ""))
        guard let content = responseContent else { return nil }
        return LLMCompletionResult(content: content, inputTokens: 10, outputTokens: 10)
    }

    func complete(system: String, user: String, service: String) async -> LLMCompletionResult? {
        completions.append((system, user, service))
        guard let content = responseContent else { return nil }
        return LLMCompletionResult(content: content, inputTokens: 10, outputTokens: 10)
    }

    func completeChat(messages: [ChatTurn], service: String) async -> LLMCompletionResult? {
        guard let content = responseContent else { return nil }
        return LLMCompletionResult(content: content, inputTokens: 10, outputTokens: 10)
    }
}
