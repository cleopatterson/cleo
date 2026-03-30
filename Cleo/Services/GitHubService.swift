import Foundation

/// Calls GitHub API directly from the app to create issues and sync status.
/// Token is loaded from Info.plist (set via Secrets.xcconfig → GITHUB_TOKEN).
struct GitHubService {
    static let shared = GitHubService()

    private let owner = "cleopatterson"
    private let repo = "cleo"

    private var token: String {
        Bundle.main.infoDictionary?["GITHUB_TOKEN"] as? String ?? ""
    }

    // MARK: - Create Issue

    /// Creates a GitHub issue for a bug report. Returns (issueNumber, issueUrl) on success.
    func createIssue(title: String, description: String, severity: BugSeverity) async -> (Int, String)? {
        guard !token.isEmpty else {
            print("[GitHub] No token configured — skipping issue creation")
            return nil
        }

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/issues")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "title": "[Bug] \(title)",
            "body": """
                **Severity:** \(severity.displayName)

                \(description)

                ---
                *Reported via Cleo app*
                """,
            "labels": ["bug-report", "severity-\(severity.rawValue)"]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
                print("[GitHub] Issue creation failed: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let number = json?["number"] as? Int,
                  let htmlUrl = json?["html_url"] as? String else { return nil }
            return (number, htmlUrl)
        } catch {
            print("[GitHub] Issue creation error: \(error)")
            return nil
        }
    }

    // MARK: - Sync Status

    /// Fetches current state of a GitHub issue. Returns updated BugStatus.
    func fetchIssueStatus(number: Int) async -> BugStatus? {
        guard !token.isEmpty else { return nil }

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/issues/\(number)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let state = json?["state"] as? String else { return nil }

            // Check for "fixed" label (added when a fix PR is merged)
            let labels = (json?["labels"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
            if labels.contains("fixed") { return .fixed }
            return state == "closed" ? .closed : .inProgress
        } catch {
            print("[GitHub] Status fetch error: \(error)")
            return nil
        }
    }
}
