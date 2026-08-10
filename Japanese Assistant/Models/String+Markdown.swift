//
//  String+Markdown.swift
//  Japanese Assistant
//

import Foundation

extension String {
    /// Drops common Markdown markers (`*`, `` ` ``, `~`, leading `#`/`>`,
    /// `[text](url)`) while preserving the text between them. Underscores
    /// are left alone so identifier-like tokens aren't mangled.
    func strippingMarkdown() -> String {
        var s = self
        s = s.replacingOccurrences(of: #"!?\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"[*`~]+"#, with: "", options: .regularExpression)
        s = s.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var l = String(line)
                l = l.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
                l = l.replacingOccurrences(of: #"^\s{0,3}>\s?"#, with: "", options: .regularExpression)
                return l
            }
            .joined(separator: "\n")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
