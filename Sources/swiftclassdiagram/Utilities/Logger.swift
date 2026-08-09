import Foundation
import SwiftClassDiagramKit

/// 轻量控制台日志实现，替代上游依赖的 SwiftyBeaver。
/// - 默认仅输出 error 级别；`verbose` 开启 debug 级别。
struct ConsoleLogger {
    private(set) var logLevel: LogLevel

    init(verbose: Bool) {
        logLevel = verbose ? .debug : .error
    }

    static func create(verbose: Bool) -> Logging {
        ConsoleLogger(verbose: verbose)
    }
}

extension ConsoleLogger: Logging {
    func error(_ message: String, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        guard logLevel >= .error else { return }
        FileHandle.standardError.write(Data("[error] \(message)\n".utf8))
    }

    func warning(_ message: String, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        guard logLevel >= .warning else { return }
        FileHandle.standardError.write(Data("[warning] \(message)\n".utf8))
    }

    func info(_ message: String, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        guard logLevel >= .info else { return }
        FileHandle.standardError.write(Data("[info] \(message)\n".utf8))
    }

    func debug(_ message: String, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        guard logLevel >= .debug else { return }
        FileHandle.standardError.write(Data("[debug] \(message)\n".utf8))
    }
}
