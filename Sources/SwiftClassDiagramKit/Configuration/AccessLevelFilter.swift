import Foundation

/// 访问级别开关集合：控制类/成员的可见性过滤。
///
/// 与模板 `elements.havingAccessLevel` / `showMembersWithAccessLevel` 一一对应，
/// 每个访问级别一个布尔开关（`true` = 允许展示）。
public struct AccessLevelFilter: Codable, Sendable {
    /// `open`：类可在模块外公开访问，且允许被外部模块继承/重写
    public var open: Bool
    /// `public`：类可在模块外公开访问，但不允许被外部模块继承
    public var `public`: Bool
    /// `internal`：类仅可在定义模块内访问（默认）
    public var `internal`: Bool
    /// `fileprivate`：类仅可在定义的文件内访问
    public var `fileprivate`: Bool
    /// `private`：类仅可在定义的作用域（外层类/枚举）内访问
    public var `private`: Bool

    public init(open: Bool = true, `public`: Bool = true, `internal`: Bool = true, `fileprivate`: Bool = false, `private`: Bool = false) {
        self.open = open
        self.public = `public`
        self.internal = `internal`
        self.fileprivate = `fileprivate`
        self.private = `private`
    }

    /// 解析为开启的 `AccessLevel` 列表（`package` 归入 `internal` 层级）。
    public var allowed: [AccessLevel] {
        var result: [AccessLevel] = []
        if open { result.append(.open) }
        if `public` { result.append(.public) }
        if `internal` {
            result.append(.internal)
            result.append(.package)
        }
        if `fileprivate` { result.append(.fileprivate) }
        if `private` { result.append(.private) }
        return result
    }
}
