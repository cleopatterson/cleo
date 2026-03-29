import Foundation

/// Response model from Claude API for tab briefings (§7.4)
struct AIBriefingResponse: Codable {
    let headline: String
    let summary: String
    let stats: [AIBriefingStat]
}

struct AIBriefingStat: Codable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

/// Cached briefing with metadata
struct CachedBriefing: Codable {
    let tab: String
    let response: AIBriefingResponse
    let dataHash: String
    let generatedAt: Date
    let tokenCount: Int?
}
