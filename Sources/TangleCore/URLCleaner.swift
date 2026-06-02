import Foundation

public struct URLCleaner: Sendable {
    public var blockedParameters: Set<String>
    public var allowedParameters: Set<String>

    public init(
        blockedParameters: Set<String> = URLCleaner.defaultBlockedParameters,
        allowedParameters: Set<String> = []
    ) {
        self.blockedParameters = Set(blockedParameters.map { $0.lowercased() })
        self.allowedParameters = Set(allowedParameters.map { $0.lowercased() })
    }

    public func cleanURLs(in input: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: #"https?://[^\s<>"\]]+"#) else {
            return input
        }

        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        var output = input

        for match in expression.matches(in: input, range: nsRange).reversed() {
            guard let range = Range(match.range, in: input) else { continue }
            let rawURL = String(input[range])
            let (urlText, trailing) = splitTrailingPunctuation(rawURL)

            guard let cleaned = cleanURLString(urlText), cleaned != urlText else { continue }
            output.replaceSubrange(range, with: cleaned + trailing)
        }

        return output
    }

    public func cleanURLString(_ urlString: String) -> String? {
        guard var components = URLComponents(string: urlString) else {
            return nil
        }

        guard let items = components.queryItems, !items.isEmpty else {
            return urlString
        }

        let filteredItems = items.filter { item in
            let name = item.name.lowercased()

            if allowedParameters.contains(name) {
                return true
            }

            if name.hasPrefix("utm_") {
                return false
            }

            return !blockedParameters.contains(name)
        }

        components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        return components.string
    }

    private func splitTrailingPunctuation(_ value: String) -> (String, String) {
        var url = value
        var trailing = ""

        while let last = url.last, [".", ",", ")", "!", "?"].contains(last) {
            url.removeLast()
            trailing.insert(last, at: trailing.startIndex)
        }

        return (url, trailing)
    }

    public static let defaultBlockedParameters: Set<String> = [
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content",
        "utm_id",
        "utm_name",
        "utm_reader",
        "utm_viz_id",
        "utm_pubreferrer",
        "fbclid",
        "gclid",
        "gbraid",
        "wbraid",
        "dclid",
        "mc_cid",
        "mc_eid",
        "mkt_tok",
        "igshid",
        "msclkid",
        "yclid",
        "ref_url",
        "smid",
        "taid",
        "taboola_id",
        "_hsenc",
        "_hsmi",
        "vero_id",
        "spm",
        "sc_channel",
        "ref_src"
    ]
}
