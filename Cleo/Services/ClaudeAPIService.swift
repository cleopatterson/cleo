import Foundation

/// Claude Haiku 4.5 API integration for AI briefings (§7)
@MainActor
@Observable
class ClaudeAPIService {
    private let model = "claude-haiku-4-5-20251001"
    private let maxTokens = 512

    // Cost controls (§7.3)
    private var dailyCallCounts: [String: Int] = [:]
    private var lastCallDate: String = ""
    private let maxCallsPerTabPerDay = 3
    private let debounceDuration: TimeInterval = 10

    private var pendingTask: Task<Void, Never>?
    private var briefingCache: [String: CachedBriefing] = [:]

    private var apiKey: String {
        Secrets.claudeAPIKey
    }

    // MARK: - Public API

    func generateBriefing(tab: TabAccent, dataPayload: [String: Any], cacheKey: String? = nil) async -> AIBriefingResponse? {
        let tabKey = cacheKey ?? tab.rawValue
        let dataHash = stableHash(dataPayload)

        // Check cache
        if let cached = briefingCache[tabKey], cached.dataHash == dataHash {
            print("[Claude] \(tabKey): returning cached briefing")
            return cached.response
        }

        // Check daily cap
        resetDailyCountsIfNeeded()
        let count = dailyCallCounts[tabKey, default: 0]
        guard count < maxCallsPerTabPerDay else {
            print("[Claude] \(tabKey): daily cap reached (\(count)/\(maxCallsPerTabPerDay))")
            return briefingCache[tabKey]?.response
        }

        // Make API call
        print("[Claude] \(tabKey): calling API (attempt \(count + 1)/\(maxCallsPerTabPerDay))")
        guard let response = await callClaude(tab: tab, payload: dataPayload) else {
            print("[Claude] \(tabKey): API call returned nil")
            return briefingCache[tabKey]?.response
        }

        // Cache result
        briefingCache[tabKey] = CachedBriefing(
            tab: tabKey,
            response: response,
            dataHash: dataHash,
            generatedAt: Date(),
            tokenCount: nil
        )
        dailyCallCounts[tabKey, default: 0] += 1

        return response
    }

    func cachedBriefing(for tab: TabAccent) -> AIBriefingResponse? {
        briefingCache[tab.rawValue]?.response
    }

    // MARK: - API Call

    private func callClaude(tab: TabAccent, payload: [String: Any]) async -> AIBriefingResponse? {
        guard !apiKey.isEmpty else { return nil }

        let systemPrompt = """
        You are an AI assistant for a business planning app called Cleo. \
        Generate a brief, insightful summary for the \(tab.label) tab. \
        Write in a warm, direct, business-savvy voice. No corporate jargon. No motivational filler. \
        Reference actual client names, amounts, and dates. Flag risks and opportunities. \
        Respond in JSON with keys: headline (string, max 60 chars), summary (string, max 200 chars), \
        stats (array of {label, value} objects, max 3 items).
        """

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let userMessage = """
        {"tab":"\(tab.rawValue)","today":"\(today)","data":\(jsonString(payload))}
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("Claude API HTTP \(httpResponse.statusCode): \(body)")
                return nil
            }
            return parseResponse(data)
        } catch {
            print("Claude API error: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseResponse(_ data: Data) -> AIBriefingResponse? {
        // Extract text content from Claude response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[Claude] parseResponse: failed to parse top-level JSON")
            return nil
        }
        guard let content = json["content"] as? [[String: Any]] else {
            print("[Claude] parseResponse: no 'content' array — keys: \(json.keys.sorted())")
            return nil
        }
        guard let text = content.first?["text"] as? String else {
            print("[Claude] parseResponse: no 'text' in first content block")
            return nil
        }
        print("[Claude] parseResponse: raw text = \(text.prefix(200))")

        // Claude sometimes wraps JSON in ```json ... ``` — strip that
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let textData = cleaned.data(using: .utf8) else {
            print("[Claude] parseResponse: failed to convert cleaned text to data")
            return nil
        }

        do {
            return try JSONDecoder().decode(AIBriefingResponse.self, from: textData)
        } catch {
            print("[Claude] parseResponse: JSON decode failed — \(error)")
            return nil
        }
    }

    // MARK: - Invoice Email Drafting

    func draftInvoiceEmail(
        clientName: String,
        invoiceNumber: String,
        total: Double,
        dueDate: Date,
        paymentTerms: String,
        businessName: String,
        lineItemSummary: String
    ) async -> String? {
        guard !apiKey.isEmpty else { return nil }

        let dueDateStr = dueDate.formatted(.dateTime.day().month(.abbreviated).year())
        let totalStr = String(format: "$%.2f", total)

        let systemPrompt = """
        You are writing a professional invoice email on behalf of a small business. \
        Write a concise, friendly, professional email body. No subject line needed. \
        Include: greeting with client name, reference to the invoice number and amount, \
        due date, and a polite sign-off with the business name. \
        Keep it under 150 words. Do not use markdown. Plain text only. \
        Do not include any preamble or explanation — just the email text.
        """

        let userMessage = """
        Draft an invoice email:
        - Client: \(clientName)
        - Invoice: \(invoiceNumber)
        - Total: \(totalStr)
        - Due: \(dueDateStr) (\(paymentTerms))
        - Business: \(businessName)
        - Services: \(lineItemSummary)
        """

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("Claude email draft HTTP \(httpResponse.statusCode): \(body)")
                return nil
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let text = content.first?["text"] as? String else { return nil }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Claude email draft error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Natural Language Event Parsing

    func parseEventFromNaturalLanguage(text: String, referenceDate: Date) async -> ParsedEventInput? {
        guard !apiKey.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: referenceDate)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayOfWeek = dayFormatter.string(from: referenceDate)

        let prompt = """
        Parse this natural language event description into structured fields.

        Input: "\(text)"
        Today is: \(todayString) (\(dayOfWeek))

        Rules:
        - If an explicit calendar date is given (e.g. "21 Mar", "March 21", "21/3"), ALWAYS use that exact date regardless of any day-of-week name also mentioned.
        - If ONLY a day name is given without a calendar date (e.g. "Friday", "next Tuesday"), use the NEXT occurrence of that day from today.
        - For multi-day events (e.g. "from 4-6 Sept", "Mon-Wed"), set DATE to the first day, END_DATE to the last day, and IS_ALL_DAY to true.
        - Strip the date, time, and location from the title.
        - Keep the venue/restaurant in the title if it's part of the event name (e.g. "Dinner at Ormeggio" keeps "at Ormeggio")
        - Round minutes to the nearest 15-minute interval (00, 15, 30, 45)
        - If no time is specified, leave TIME empty
        - If no date is specified, use today's date
        - IS_ALL_DAY should be true if explicitly stated or if the event spans multiple days.

        Respond in EXACTLY this format (one field per line, no extra text):
        TITLE: <event title with location but without date/time>
        DATE: <YYYY-MM-DD>
        END_DATE: <YYYY-MM-DD if multi-day, or empty>
        TIME: <HH:MM in 24h format, or empty>
        LOCATION: <location if mentioned separately from title, or empty>
        IS_ALL_DAY: <true or false>
        """

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 200,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("Claude event parse HTTP \(httpResponse.statusCode): \(body)")
                return nil
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let responseText = content.first?["text"] as? String else { return nil }
            return ParsedEventInput.parse(from: responseText, referenceDate: referenceDate)
        } catch {
            print("Claude event parse error: \(error.localizedDescription)")
            return nil
        }
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    // MARK: - Receipt Scanning (Vision)

    struct ParsedReceipt {
        var amount: Double?
        var category: String?
        var date: Date?
        var vendor: String?
        var description: String?
    }

    func parseReceiptImage(_ imageData: Data) async -> ParsedReceipt? {
        guard !apiKey.isEmpty else { return nil }

        let base64 = imageData.base64EncodedString()

        let prompt = """
        Analyze this receipt image and extract the following details.

        Rules:
        - Extract the TOTAL amount paid (not subtotal, the final amount including tax/GST)
        - Identify the vendor/store name
        - Extract the date of purchase
        - Write a short description of what was purchased (max 10 words)
        - Categorise into one of: Software, Equipment, Travel, Advertising, Subscriptions, Materials, Other

        Respond in EXACTLY this format (one field per line, no extra text):
        AMOUNT: <numeric amount, no currency symbol>
        VENDOR: <store/vendor name>
        DATE: <YYYY-MM-DD>
        DESCRIPTION: <short description of purchase>
        CATEGORY: <one of: Software, Equipment, Travel, Advertising, Subscriptions, Materials, Other>
        """

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64
                        ]
                    ],
                    [
                        "type": "text",
                        "text": prompt
                    ]
                ]
            ]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("Claude receipt scan HTTP \(httpResponse.statusCode): \(body)")
                return nil
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let responseText = content.first?["text"] as? String else { return nil }
            return parseReceiptResponse(responseText)
        } catch {
            print("Receipt scan error: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseReceiptResponse(_ text: String) -> ParsedReceipt {
        var receipt = ParsedReceipt()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("AMOUNT:") {
                let val = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                receipt.amount = Double(val.replacingOccurrences(of: ",", with: ""))
            } else if trimmed.hasPrefix("VENDOR:") {
                let val = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { receipt.vendor = val }
            } else if trimmed.hasPrefix("DATE:") {
                let val = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                receipt.date = dateFormatter.date(from: val)
            } else if trimmed.hasPrefix("DESCRIPTION:") {
                let val = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { receipt.description = val }
            } else if trimmed.hasPrefix("CATEGORY:") {
                let val = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { receipt.category = val }
            }
        }

        return receipt
    }

    // MARK: - Helpers

    private func stableHash(_ dict: [String: Any]) -> String {
        let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys)
        return data?.base64EncodedString() ?? ""
    }

    private func jsonString(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    private func resetDailyCountsIfNeeded() {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let todayStr = String(today)
        if lastCallDate != todayStr {
            dailyCallCounts.removeAll()
            lastCallDate = todayStr
        }
    }
}
