import Foundation

public struct TransformationStats: Equatable, Sendable {
    public let inputCharacters: Int
    public let outputCharacters: Int
    public let characterDelta: Int
    public let estimatedInputTokens: Int
    public let estimatedOutputTokens: Int
    public let estimatedTokenDelta: Int

    public init(input: String, output: String) {
        inputCharacters = input.count
        outputCharacters = output.count
        characterDelta = inputCharacters - outputCharacters
        estimatedInputTokens = Self.estimatedTokens(for: input)
        estimatedOutputTokens = Self.estimatedTokens(for: output)
        estimatedTokenDelta = estimatedInputTokens - estimatedOutputTokens
    }

    public static func estimatedTokens(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return Int((Double(text.count) / 4.0).rounded(.up))
    }
}
