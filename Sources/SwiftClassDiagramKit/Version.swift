/// A type describing the SwiftClassDiagram version.
public struct Version {
    /// The string value for this version.
    public let value: String

    /// 基于 SwiftPlantUML 0.8.1 (MIT) 移植，v1.0.0 起为独立版本。
    public static let current = Version(value: "1.0.5")
}
