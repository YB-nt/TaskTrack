import Foundation

/// Fetches a single file's raw text from a GitHub repo, given a URL copy-pasted straight out
/// of the browser (a `github.com/.../blob/...` page, or a `raw.githubusercontent.com` link).
/// Used by `TaskDocumentStore` as an alternative to manually downloading a file before adding
/// it — the source of truth is still a plain local file afterward (see `cacheGitHubFile`), it's
/// just fetched instead of hand-picked.
public enum GitHubFileFetcher {
    public struct Reference: Equatable {
        public var owner: String
        public var repo: String
        public var ref: String
        public var path: String

        public init(owner: String, repo: String, ref: String, path: String) {
            self.owner = owner
            self.repo = repo
            self.ref = ref
            self.path = path
        }
    }

    public enum FetchError: Error, LocalizedError {
        case invalidURL
        case httpError(Int)
        case decodingFailed

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "GitHub 파일 URL 형식을 인식할 수 없습니다. github.com/.../blob/... 링크나 raw.githubusercontent.com 링크를 붙여넣어 주세요."
            case .httpError(404):
                return "GitHub에서 파일을 찾을 수 없습니다 (경로/브랜치를 확인해 주세요, 비공개 저장소면 토큰이 필요합니다)."
            case .httpError(let code):
                return "GitHub에서 파일을 가져오지 못했습니다 (HTTP \(code))."
            case .decodingFailed:
                return "가져온 내용을 텍스트로 해석할 수 없습니다."
            }
        }
    }

    /// Recognizes `https://github.com/{owner}/{repo}/blob/{ref}/{path...}` and
    /// `https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{path...}`.
    public static func parse(_ url: URL) -> Reference? {
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host {
        case "raw.githubusercontent.com":
            guard parts.count >= 4 else { return nil }
            return Reference(owner: parts[0], repo: parts[1], ref: parts[2], path: parts[3...].joined(separator: "/"))
        case "github.com":
            guard parts.count >= 5, parts[2] == "blob" else { return nil }
            return Reference(owner: parts[0], repo: parts[1], ref: parts[3], path: parts[4...].joined(separator: "/"))
        default:
            return nil
        }
    }

    /// Uses the GitHub Contents API (rather than raw.githubusercontent.com directly) so the
    /// same code path works for both public repos (no token) and private ones (bearer token) —
    /// `Accept: application/vnd.github.raw` returns the file's raw bytes instead of the
    /// default base64-wrapped JSON envelope.
    public static func fetchContent(_ reference: Reference, token: String?) async throws -> String {
        let encodedPath = reference.path
            .split(separator: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        var components = URLComponents(string: "https://api.github.com/repos/\(reference.owner)/\(reference.repo)/contents/\(encodedPath)")
        components?.queryItems = [URLQueryItem(name: "ref", value: reference.ref)]
        guard let url = components?.url else { throw FetchError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.raw", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FetchError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let text = String(data: data, encoding: .utf8) else { throw FetchError.decodingFailed }
        return text
    }
}
