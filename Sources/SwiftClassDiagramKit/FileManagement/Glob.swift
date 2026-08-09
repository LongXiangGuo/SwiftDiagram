import Foundation

//
//  Globs.swift
//  SwiftFormat
//
//  Created by Nick Lockwood on 31/12/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//

func pathContainsGlobSyntax(_ path: String) -> Bool {
    "*?[{".contains(where: { path.contains($0) })
}

/// Glob type represents either an exact path or wildcard
internal enum Glob: CustomStringConvertible {
    case path(String)
    case regex(NSRegularExpression)

    internal func matches(_ path: String) -> Bool {
        switch self {
        case let .path(_path):
            return _path == path || path.contains(_path)
        case let .regex(regex):
            let range = NSRange(location: 0, length: path.utf16.count)
            return regex.firstMatch(in: path, options: [], range: range) != nil
        }
    }

    internal var description: String {
        switch self {
        case let .path(path):
            return path
        case let .regex(regex):
            var result = regex.pattern.dropFirst().dropLast()
                .replacingOccurrences(of: "([^/]+)?", with: "*")
                .replacingOccurrences(of: "(.+/)?", with: "**/")
                .replacingOccurrences(of: ".+", with: "**")
                .replacingOccurrences(of: "[^/]", with: "?")
                .replacingOccurrences(of: "\\", with: "")
            while let range = result.range(of: "\\([^)]+\\)", options: .regularExpression) {
                let options = result[range].dropFirst().dropLast().components(separatedBy: "|")
                result.replaceSubrange(range, with: "{\(options.joined(separator: ","))}")
            }
            return result
        }
    }
}

// Parse a comma-delimited list of items
func parseCommaDelimitedList(_ string: String) -> [String] {
    string.components(separatedBy: ",").compactMap {
        let item = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        return item.isEmpty ? nil : item
    }
}

internal func expandPath(_ path: String, in directory: String) -> URL {
    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path)
    }
    if path.hasPrefix("~") {
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }
    return URL(fileURLWithPath: directory).appendingPathComponent(path)
}

/// Expand one or more comma-delimited file paths using glob syntax
internal func expandGlobs(_ paths: String, in directory: String) -> [Glob] {
    guard pathContainsGlobSyntax(paths) else {
        return parseCommaDelimitedList(paths).map {
            .path(expandPath($0, in: directory).path)
        }
    }
    var paths = paths
    var tokens = [String: String]()
    while let range = paths.range(of: "\\{[^}]+\\}", options: .regularExpression) {
        let options = paths[range].dropFirst().dropLast()
            .replacingOccurrences(of: "[.+(){\\\\|]", with: "\\\\$0", options: .regularExpression)
            .components(separatedBy: ",")
        let token = "<<<\(tokens.count)>>>"
        tokens[token] = "(\(options.joined(separator: "|")))"
        paths.replaceSubrange(range, with: token)
    }
    return parseCommaDelimitedList(paths).map { path -> Glob in
        let path = expandPath(path, in: directory).path
        if FileManager.default.fileExists(atPath: path) {
            // TODO: should we also handle cases where path includes tokens?
            return .path(path)
        }
        var regex = "^\(path)$"
            .replacingOccurrences(of: "[.+(){\\\\|]", with: "\\\\$0", options: .regularExpression)
            .replacingOccurrences(of: "?", with: "[^/]")
            .replacingOccurrences(of: "**/", with: "(.+/)?")
            .replacingOccurrences(of: "**", with: ".+")
            .replacingOccurrences(of: "*", with: "([^/]+)?")
        for (token, replacement) in tokens {
            regex = regex.replacingOccurrences(of: token, with: replacement)
        }
        return try! .regex(NSRegularExpression(pattern: regex, options: []))
    }
}

func matchGlobs(_ globs: [Glob], in directory: String) -> [URL] {
    var urls = [URL]()
    let keys: [URLResourceKey] = [.isDirectoryKey]
    let manager = FileManager.default
    func enumerate(_ directory: URL) {
        guard let files = try? manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: []
        ) else {
            return
        }
        for url in files {
            let path = url.path
            var isDirectory: ObjCBool = false
            if globs.contains(where: { $0.matches(path) }) {
                urls.append(url)
            } else if manager.fileExists(atPath: path, isDirectory: &isDirectory),
                      isDirectory.boolValue
            {
                enumerate(url)
            }
        }
    }
    enumerate(URL(fileURLWithPath: directory))
    return urls
}

/// 判断目录下的 Swift 文件是否全部被 `exclude` 模式排除。
///
/// 用于 Web 控制台 group 候选目录过滤：目录中不含 Swift 文件或全部文件均被
/// `files.exclude` 命中时，该目录不应出现在默认分组列表中。
///
/// - Parameters:
///   - directory: 待检查的目录。
///   - excludePatterns: `files.exclude` 通配符列表。
///   - root: exclude 相对路径的基准目录（通常为执行目录）。
/// - Returns: `true` 表示目录下存在 Swift 文件且全部被排除；无 Swift 文件返回 `false`。
public func isDirectoryExcluded(
    _ directory: URL,
    by excludePatterns: [String],
    relativeTo root: String
) -> Bool {
    guard !excludePatterns.isEmpty else { return false }
    let globs = expandGlobs(excludePatterns.joined(separator: ","), in: root)
    var swiftFiles: [URL] = []
    if let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) {
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "swift" {
            swiftFiles.append(url)
        }
    }
    guard !swiftFiles.isEmpty else { return false }
    return swiftFiles.allSatisfy { file in
        globs.contains { $0.matches(file.path) }
    }
}

/// 判断目录下是否存在 Swift 文件（递归）。
///
/// - Parameter directory: 待检查的目录。
/// - Returns: `true` 表示目录内存在 `.swift` 文件。
public func directoryContainsSwiftFile(_ directory: URL) -> Bool {
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
        return false
    }
    for case let url as URL in enumerator where url.pathExtension.lowercased() == "swift" {
        return true
    }
    return false
}
