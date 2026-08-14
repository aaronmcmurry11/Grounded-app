import Foundation
import Observation

nonisolated struct ChatMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case grounded
    }

    let id = UUID()
    let role: Role
    let text: String
    /// Remedy suggestions rendered as distinct cards beneath the message.
    var suggestions: [Remedy] = []
    var isError: Bool = false
}

/// Prompted chat: every message is answered by the language model. The bundled
/// library is offered to the model as its only citable catalog, and remedy cards
/// appear only for ids the model returns as a genuine match.
@Observable
final class ChatModel {
    var messages: [ChatMessage] = [
        ChatMessage(
            role: .grounded,
            text: "Ask me about an ingredient, a food, or a remedy — I'll tell you how traditional and ancestral approaches see it, and the reasoning behind why. I'll share an entry from the library when one genuinely fits. Educational information only, never a diagnosis."
        ),
    ]
    var draft: String = ""
    var isThinking = false

    private let library: RemedyLibrary
    private let service = GroundedChatService()

    init(library: RemedyLibrary) {
        self.library = library
    }

    func prefill(followUpFor remedy: Remedy) {
        draft = "About \(remedy.name) — "
    }

    func send() async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking else { return }

        draft = ""
        messages.append(ChatMessage(role: .user, text: question))
        isThinking = true
        defer { isThinking = false }

        do {
            let turn = try await service.reply(to: messages, catalog: library.remedies)
            let suggestions = turn.remedyIds.compactMap { library.remedy(id: $0) }
            messages.append(
                ChatMessage(
                    role: .grounded,
                    text: turn.reply.isEmpty ? "I'm not sure how to answer that one. Could you say a bit more?" : turn.reply,
                    suggestions: suggestions
                )
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "Something went wrong reaching Grounded. Please try again."
            print("[ChatModel] reply failed: \(String(describing: type(of: error)))")
            messages.append(ChatMessage(role: .grounded, text: message, isError: true))
        }
    }

    /// Retries the last question after a failed turn.
    func retryLast() async {
        guard !isThinking else { return }
        guard let lastError = messages.last, lastError.isError else { return }
        guard let question = messages.last(where: { $0.role == .user })?.text else { return }
        messages.removeLast()
        draft = question
        // Drop the original question so it isn't duplicated in the thread.
        if let index = messages.lastIndex(where: { $0.role == .user }) {
            messages.remove(at: index)
        }
        await send()
    }
}
