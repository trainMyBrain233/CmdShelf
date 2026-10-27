import Foundation
import Markdown

struct CodeBlock: Identifiable, Hashable {
    enum Origin: String {
        case fenced
        case indented
    }

    var id: UUID = UUID()
    var language: String?
    var content: String
    var range: Range<String.Index>?
    var origin: Origin
}

protocol MarkdownCodeBlockExtractorProtocol {
    func extract(from markdown: String) -> [CodeBlock]
}

final class MarkdownCodeBlockExtractor: MarkdownCodeBlockExtractorProtocol {
    func extract(from markdown: String) -> [CodeBlock] {
        let document = Document(parsing: markdown)
        var blocks: [CodeBlock] = []
        walk(node: document, into: &blocks)
        return blocks
    }

    private func walk(node: Markup, into blocks: inout [CodeBlock]) {
        if let block = node as? Markdown.CodeBlock {
            let rendered = block.format()
            let parsed = parseRenderedCodeBlock(rendered)
            blocks.append(
                CodeBlock(
                    language: parsed.language,
                    content: parsed.content,
                    range: nil,
                    origin: parsed.origin
                )
            )
        }

        for child in node.children {
            walk(node: child, into: &blocks)
        }
    }

    private func parseRenderedCodeBlock(_ rendered: String) -> (language: String?, content: String, origin: CodeBlock.Origin) {
        let normalized = rendered.replacingOccurrences(of: "\r\n", with: "\n")

        if normalized.hasPrefix("```") {
            var lines = normalized.components(separatedBy: "\n")
            guard !lines.isEmpty else {
                return (nil, normalized, .fenced)
            }

            let firstLine = lines.removeFirst()
            let language = String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)

            if let last = lines.last, last.hasPrefix("```") {
                _ = lines.removeLast()
            }

            return (language.isEmpty ? nil : language, lines.joined(separator: "\n"), .fenced)
        }

        let lines = normalized.components(separatedBy: "\n")
        let stripped = lines.map { line -> String in
            if line.hasPrefix("    ") {
                return String(line.dropFirst(4))
            }
            if line.hasPrefix("\t") {
                return String(line.dropFirst())
            }
            return line
        }

        return (nil, stripped.joined(separator: "\n"), .indented)
    }
}
