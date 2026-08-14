import Foundation

/// One conversational turn returned by the model: the reply text, plus the ids of
/// remedies the model judged genuinely relevant (may be empty — cards are only
/// surfaced on a real match, never on a keyword hit).
nonisolated struct ChatTurn {
    let reply: String
    let remedyIds: [String]
}

/// Talks to the Rork toolkit proxy (OpenAI-compatible chat completions) so every
/// message gets a real generated reply. The bundled library is passed in the system
/// prompt as the only catalog the model may cite — full retrieval comes later.
nonisolated struct GroundedChatService {
    private let model = "anthropic/claude-haiku-4.5"
    private let fallbackModels = ["google/gemini-3.5-flash", "openai/gpt-5-mini"]

    private nonisolated struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
            let finish_reason: String?
        }
        let choices: [Choice]
    }

    private nonisolated struct ModelPayload: Decodable {
        let reply: String
        let remedyIds: [String]?
    }

    func reply(
        to history: [ChatMessage],
        catalog: [Remedy]
    ) async throws -> ChatTurn {
        let base = Config.EXPO_PUBLIC_TOOLKIT_URL.trimmingCharacters(in: .whitespaces)
        let secret = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !base.isEmpty, !secret.isEmpty,
              let url = URL(string: "\(base)/v2/vercel/v1/chat/completions") else {
            throw ProxyError.notConfigured
        }

        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt(catalog: catalog)],
        ]
        // Keep the window small — recent turns are what make it feel conversational.
        for message in history.suffix(12) where !message.isError {
            messages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.text,
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            // Lower than a general chat default: this app's answers need to stay
            // factually tight, and creative variance is where invented statistics,
            // dates, and regulatory claims come from.
            "temperature": 0.4,
            // Generous headroom: answers now run longer and more substantive, and the
            // JSON envelope must always be able to close. Truncation here is what
            // produced raw, half-finished JSON in the bubble.
            "max_tokens": 2000,
            "providerOptions": ["gateway": ["models": fallbackModels]],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, _) = try await sendWithRetry(request)
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let choice = decoded.choices.first,
              let content = choice.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProxyError.noData
        }

        return try parse(content: content, wasTruncated: choice.finish_reason == "length", catalog: catalog)
    }

    /// Three-stage recovery so the user never sees machine output:
    /// 1. Clean JSON — the normal path.
    /// 2. Malformed or truncated JSON — salvage the `reply` string on its own.
    /// 3. Plain prose with no JSON at all — use it verbatim.
    /// Anything still unusable throws, so the UI shows a retryable error instead.
    private func parse(content: String, wasTruncated: Bool, catalog: [Remedy]) throws -> ChatTurn {
        let validIds = Set(catalog.map(\.id))

        if let json = extractJSONObject(from: content),
           let payload = try? JSONDecoder().decode(ModelPayload.self, from: Data(json.utf8)) {
            let ids = (payload.remedyIds ?? []).filter { validIds.contains($0) }
            return ChatTurn(
                reply: tidy(payload.reply, wasTruncated: wasTruncated),
                remedyIds: Array(ids.prefix(2))
            )
        }

        if let salvaged = salvageReplyValue(from: content) {
            print("[GroundedChatService] malformed JSON envelope, salvaged reply text")
            return ChatTurn(reply: tidy(salvaged, wasTruncated: wasTruncated), remedyIds: [])
        }

        // Never surface raw JSON: if it still looks like machine output, treat the
        // turn as failed rather than printing braces into the thread.
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.contains("\"reply\"") || trimmed.contains("\"remedyIds\"") {
            print("[GroundedChatService] unparseable JSON envelope, treating turn as failed")
            throw ProxyError.noData
        }

        return ChatTurn(reply: tidy(trimmed, wasTruncated: wasTruncated), remedyIds: [])
    }

    /// Trims a cut-off answer back to its last complete sentence so a truncated
    /// reply reads as finished rather than stopping mid-word.
    private func tidy(_ reply: String, wasTruncated: Bool) -> String {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard wasTruncated, !trimmed.isEmpty else { return trimmed }

        if let lastStop = trimmed.lastIndex(where: { ".!?".contains($0) }) {
            let sentence = String(trimmed[...lastStop]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count > 40 { return sentence }
        }
        return trimmed + "…"
    }

    private func extractJSONObject(from content: String) -> String? {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}"),
              start < end else { return nil }
        return String(content[start...end])
    }

    /// Pulls the value of `"reply"` out of a JSON string that may never close —
    /// walks the string honoring escapes and stops at the first unescaped quote or
    /// at the end of the truncated input.
    private func salvageReplyValue(from content: String) -> String? {
        guard let key = content.range(of: "\"reply\"") else { return nil }

        var index = key.upperBound
        // Advance past the colon and any whitespace to the opening quote.
        while index < content.endIndex, content[index] != "\"" {
            guard content[index] == ":" || content[index].isWhitespace else { return nil }
            index = content.index(after: index)
        }
        guard index < content.endIndex else { return nil }
        index = content.index(after: index)

        var output = ""
        var isEscaping = false

        while index < content.endIndex {
            let character = content[index]

            if isEscaping {
                switch character {
                case "n": output.append("\n")
                case "t": output.append("\t")
                case "r": break
                case "u":
                    let start = content.index(after: index)
                    if let end = content.index(start, offsetBy: 4, limitedBy: content.endIndex),
                       let value = UInt32(content[start..<end], radix: 16),
                       let scalar = Unicode.Scalar(value) {
                        output.append(Character(scalar))
                        index = content.index(before: end)
                    }
                default: output.append(character)
                }
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else if character == "\"" {
                break
            } else {
                output.append(character)
            }

            index = content.index(after: index)
        }

        let salvaged = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return salvaged.isEmpty ? nil : salvaged
    }

    private func systemPrompt(catalog: [Remedy]) -> String {
        let entries = catalog.map { remedy in
            "- id: \(remedy.id) | \(remedy.name) | category: \(remedy.category) | traditionally used for: \(remedy.ailment) | \(remedy.shortDescription)"
        }.joined(separator: "\n")

        return """
        You are Grounded, a knowledgeable, plain-spoken guide to traditional and \
        ancestral-health approaches to food, ingredients, and home remedies. You exist to \
        give people the traditional perspective clearly and specifically — not to hedge.

        VOICE
        - Lead with what traditional and ancestral-health sources actually say, and explain \
        the specific reasoning behind it: how something is made, processed, or used, and why \
        that matters. Mechanism and specifics are what make an answer useful.
        - Be confident and direct. Take a clear position and explain the thinking behind it.
        - Do NOT write vague both-sides answers. "Some people think X, others think Y", \
        "that's contested", and "there's no clear answer" are non-answers. Never open that way.
        - Do NOT reflexively tack "consult a doctor" or "ask a dietitian" onto general \
        informational questions. That belongs only in genuinely personal medical situations \
        (see PERSONAL QUESTIONS).
        - 3-6 sentences of real substance. Conversational prose — no headings, no bullet \
        lists, no markdown. No filler openers like "Great question".
        - Where it's useful, close with the practical traditional alternative rather than a \
        caveat.

        CONFIDENT BUT HONEST
        Confident does not mean more certain than the evidence supports. These go together:
        - When something is a traditional or values-based perspective rather than an \
        established fact, say so plainly — "traditional approaches are skeptical of this, \
        because..." is a confident, clear, honest answer. Naming it as a perspective is not \
        hedging; pretending it's settled science would be dishonest.
        - Never assert as proven fact something that isn't. Do not claim a food or additive \
        causes disease if that isn't established. Distinguish clearly between "here is the \
        traditional reasoning for avoiding this" and "this is a demonstrated harm".
        - Where a debate genuinely is unresolved, say so once, specifically, and move on — \
        name what's actually unresolved instead of retreating into both-sides language.

        ACCURACY IS NON-NEGOTIABLE
        This app's credibility depends on being right, not on sounding convincing.
        - Every comparative, regulatory, or study claim must be accurate — what a regulator \
        actually requires, what a study actually found. Not the popular internet version.
        - Widely circulated claims are frequently wrong or overstated. Common examples to \
        avoid repeating: that the EU or other countries "ban" additives that are in fact \
        permitted with conditions; that an ingredient is "banned in Europe" when it is \
        restricted, relabeled, or simply not used; inflated study findings; invented numbers.
        - Never invent or approximate a statistic, date, dose, study, or regulation.
        - If you cannot state a claim accurately, LEAVE IT OUT. A shorter answer without the \
        persuasive-sounding detail is always better than an inaccurate one. Losing a talking \
        point costs nothing; being wrong costs the app its credibility.
        - Prefer the precise version of a claim over the dramatic one. The precise version is \
        usually more persuasive anyway. For example, on Red 40 / Allura Red (E129): the EU \
        does NOT ban it, but has required the warning "may have an adverse effect on activity \
        and attention in children" since 2010, after a UK government-funded study (Southampton, \
        McCann 2007) linked it and several other dyes to hyperactivity in children — and that \
        labelling requirement alone led many European manufacturers to reformulate without it. \
        Note also that EU regulators judged the evidence limited and left the intake limit \
        unchanged. That full, accurate picture is stronger than "banned in Europe", which is false.

        HARD RULES
        - You are an educational reference, not a clinician. Never diagnose.
        - Never claim anything cures, treats, prevents, or heals a disease.
        - Never give a dose the person should take. Point to the remedy entry instead.
        - Never tell someone to start, stop, or change a prescribed medication.
        - You have no access to the person's medical history. Do not assume any.

        PERSONAL QUESTIONS
        When someone describes their own symptoms, a condition they have, pregnancy, a child's \
        health, or medications they take, that is a personal medical question — answer the \
        informational part as usual, and there recommend a clinician, once, specifically \
        (and for anything severe, persistent, or worsening). For general informational \
        questions, do not add it at all.

        REMEDY CARDS
        - You may reference ONLY the catalog below, by id, and only when a remedy is a genuine \
        match for what the person asked about. A shared word is NOT a match — if someone asks \
        whether seed oils are unhealthy, that is not a match for a remedy that merely contains \
        a seed. When nothing genuinely fits, return an empty list and just answer in prose.
        - At most 2 ids. Do not name remedies that are not in the catalog.
        - Do not repeat the full contents of a card in your reply — the card is shown \
        alongside it. Refer to it briefly.

        CATALOG
        \(entries)

        OUTPUT
        Reply with a single, complete JSON object and nothing else — no code fences, no \
        commentary before or after. Write the full answer, then always close the object \
        properly. Escape any quotes inside "reply":
        {"reply": "your conversational answer", "remedyIds": ["id", ...]}
        """
    }
}
