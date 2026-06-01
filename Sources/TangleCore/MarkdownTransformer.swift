import Foundation

public struct MarkdownTransformer: Sendable {
    public init() {}

    public func transform(_ input: String) -> String {
        TextCleaner().clean(input)
            .replacingOccurrences(of: #"^[•·]\s+"#, with: "- ", options: .regularExpression)
    }
}
