import Foundation

/// 一条类型间关系（度量报告用）。
///
/// - kind 取值：`inheritance`（继承）/ `realize`（实现协议）/ `association`（关联=方法依赖）/
///   `composition`（组合=属性/构造器依赖）
public struct RelationshipMetric: Codable, Sendable {
    /// 源类型（发起依赖的一方）
    public let source: String
    /// 目标类型（被依赖的一方）
    public let target: String
    /// 关系类型
    public let kind: String

    public init(source: String, target: String, kind: String) {
        self.source = source
        self.target = target
        self.kind = kind
    }
}

/// 单个类型（类 / 结构体 / 枚举 / 协议 / 扩展）的设计复杂度度量。
public struct ClassMetrics: Codable, Sendable {
    /// 全限定类型名（如 `CrossNetworkDomain.Frame`）
    public let typeName: String
    /// 短名（如 `Frame`）
    public let displayName: String
    /// 类型种类：class / struct / enum / protocol / extension
    public let kind: String
    /// 所属模块（group 名，未配置时回退为源文件所在文件夹名）
    public let module: String
    /// 源文件路径
    public let filePath: String
    /// 访问级别：open / public / internal / private / fileprivate
    public let accessLevel: String
    /// 属性数（var.instance + var.static）
    public let propertyCount: Int
    /// 方法数（function.method.* + constructor）
    public let methodCount: Int
    /// 私有成员数（private + fileprivate 的属性与方法）
    public let privateMemberCount: Int
    /// 公开成员数（open + public 的属性与方法）
    public let publicMemberCount: Int
    /// 内部成员数（internal + package）
    public let internalMemberCount: Int
    /// 静态成员数（static 属性 + static 方法）
    public let staticMemberCount: Int
    /// 继承类型数（父类 + 遵循协议，统称）
    public let inheritedTypeCount: Int
    /// 扩展数（同名 extension 声明数量）
    public let extensionCount: Int
    /// 泛型参数数
    public let genericParameterCount: Int
    /// 出边依赖（本类型依赖他人）
    public let outgoing: [RelationshipMetric]
    /// 入边依赖（他人依赖本类型）
    public let incoming: [RelationshipMetric]
    /// 设计复杂度分数 = 属性 + 方法 + 2×继承 + 2×扩展 + 出边依赖
    public let complexityScore: Int

    public init(
        typeName: String, displayName: String, kind: String, module: String,
        filePath: String, accessLevel: String,
        propertyCount: Int, methodCount: Int,
        privateMemberCount: Int, publicMemberCount: Int, internalMemberCount: Int,
        staticMemberCount: Int, inheritedTypeCount: Int, extensionCount: Int,
        genericParameterCount: Int,
        outgoing: [RelationshipMetric], incoming: [RelationshipMetric],
        complexityScore: Int
    ) {
        self.typeName = typeName
        self.displayName = displayName
        self.kind = kind
        self.module = module
        self.filePath = filePath
        self.accessLevel = accessLevel
        self.propertyCount = propertyCount
        self.methodCount = methodCount
        self.privateMemberCount = privateMemberCount
        self.publicMemberCount = publicMemberCount
        self.internalMemberCount = internalMemberCount
        self.staticMemberCount = staticMemberCount
        self.inheritedTypeCount = inheritedTypeCount
        self.extensionCount = extensionCount
        self.genericParameterCount = genericParameterCount
        self.outgoing = outgoing
        self.incoming = incoming
        self.complexityScore = complexityScore
    }
}

/// 模块（文件夹 / 分组）级度量：类型数 + 与其他模块的耦合方向与强度。
public struct ModuleMetrics: Codable, Sendable {
    /// 模块名（group 名或文件夹名）
    public let name: String
    /// 模块路径（首个命中该模块的源文件目录）
    public let path: String
    /// 模块内类型数
    public let typeCount: Int
    /// 出边耦合：目标模块名 → 依赖关系数（本模块依赖他人）
    public let outgoingCoupling: [String: Int]
    /// 入边耦合：源模块名 → 依赖关系数（他人依赖本模块）
    public let incomingCoupling: [String: Int]

    public init(name: String, path: String, typeCount: Int, outgoingCoupling: [String: Int], incomingCoupling: [String: Int]) {
        self.name = name
        self.path = path
        self.typeCount = typeCount
        self.outgoingCoupling = outgoingCoupling
        self.incomingCoupling = incomingCoupling
    }
}

/// 模块耦合矩阵：`values[i][j]` = labels[i] 模块依赖 labels[j] 模块的关系数（跨模块）。
public struct CouplingMatrix: Codable, Sendable {
    /// 行 / 列模块名（行 == 列 == 同一集合）
    public let labels: [String]
    /// 二维矩阵，`values[i][j]` 表示第 i 个模块依赖第 j 个模块的关系数
    public let values: [[Int]]

    public init(labels: [String], values: [[Int]]) {
        self.labels = labels
        self.values = values
    }
}

/// 完整度量报告。
public struct MetricsReport: Codable, Sendable {
    /// 生成时间（ISO8601）
    public let generatedAt: String
    /// 类型总数
    public let totalTypeCount: Int
    /// 扫描文件数
    public let totalFileCount: Int
    /// 各模块度量
    public let modules: [ModuleMetrics]
    /// 模块耦合矩阵
    public let couplingMatrix: CouplingMatrix
    /// 全部类型度量
    public let classes: [ClassMetrics]
    /// 按设计复杂度分数降序的类型排名
    public let complexityRanking: [ClassMetrics]

    public init(
        generatedAt: String, totalTypeCount: Int, totalFileCount: Int,
        modules: [ModuleMetrics], couplingMatrix: CouplingMatrix,
        classes: [ClassMetrics], complexityRanking: [ClassMetrics]
    ) {
        self.generatedAt = generatedAt
        self.totalTypeCount = totalTypeCount
        self.totalFileCount = totalFileCount
        self.modules = modules
        self.couplingMatrix = couplingMatrix
        self.classes = classes
        self.complexityRanking = complexityRanking
    }
}
