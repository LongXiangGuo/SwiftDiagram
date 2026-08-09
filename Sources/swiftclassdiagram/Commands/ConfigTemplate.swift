import Foundation

/// 配置文件模板（`.swiftplantuml.yml`）。
///
/// 覆盖全部配置板块并逐块注释说明；部分可选功能默认关闭（disable），
/// 便于开箱即用、按需开启。内容与 `Configuration` 模型及 README 配置章节一致。
enum ConfigTemplate {
    /// 模板 YAML 文本。
    static let yaml = """
    # ============================================================
    # SwiftClassDiagram 配置文件模板
    # 生成：swiftclassdiagram init（serve 在缺少配置时也会自动生成）
    #
    # 全部字段均可省略，省略即用默认值。本模板覆盖所有板块，并将
    # 部分可选功能默认关闭（disable），按需打开对应开关即可。
    # ============================================================

    # ---------- 1. 文件收集规则 (files) ----------
    # include / exclude 均为 glob 列表；留空 = 收集当前目录全部 Swift 文件。
    files:
      include: []              # 只收集命中的文件，如 ["Sources/**/*.swift"]
      exclude: []              # 排除命中的文件/目录，如 [".build", "Tests"]

    # ---------- 2. 元素规则 (elements) ----------
    # 控制类型与成员在类图中的可见性。
    elements:
      # 排除这些类型（支持通配符 *），如 "@unchecked Sendable"
      exclude: []

      # 类型本身按访问级别过滤：true = 该访问级别的类型会绘制。
      havingAccessLevel:
        open: true
        public: true
        internal: true
        fileprivate: false     # 默认关闭（不绘制 fileprivate 类型）
        private: false         # 默认关闭（不绘制 private 类型）

      # 成员（方法/属性）按访问级别过滤，结构同上。
      showMembersWithAccessLevel:
        open: true
        public: true
        internal: true
        fileprivate: false
        private: false

      # 以下可选功能默认关闭（disable），按需打开：
      showNestedTypes: false   # 是否绘制嵌套类型
      showExtensions: false    # 是否绘制 extension
      showGenerics: false      # 是否绘制泛型参数

      # 五类关系开关（默认仅 inheritance 开启，其余 disable）
      relationships:
        inheritance:           # 继承 + 协议实现（<|-- / <|..）
          toggle: true
          exclude: []          # 排除的关系目标类型，支持通配符 *
        association:           # 关联：方法签名引用（-->）
          toggle: false        # 默认关闭，需要时改为 true
          exclude: []
        aggregation:           # 聚合：属性/初始化器依赖，非拥有语义（o--）
          toggle: false
          exclude: []
        composition:           # 组合：属性/初始化器依赖，拥有语义（*--）
          toggle: false
          exclude: []
        dependency:            # 扩展依赖：extension 与主类型连接（<..）
          toggle: false
          exclude: []

    # ---------- 3. 分组设置 (groupSettings) ----------
    # 按文件夹把类型聚合为 UML package；group 级配置可覆盖全局规则。
    groupSettings:
      # 分组定义（示例，请按项目实际目录调整 folder）
      groups:
        - name: Core            # 分组名（package 标题）
          folder: Sources/Core  # 归属该组的文件夹，支持通配符 *
          enable: true          # 是否启用该组
        - name: App
          folder: Sources/App
          enable: true

      # group 级 elements 覆盖（优先级最高，仅启用任意 group 时生效）
      elements:
        enable: false           # 是否启用 group 级覆盖
        exclude: ["$(inherit)"] # $(inherit) = 继承全局 exclude 并追加
        # havingAccessLevel / showMembersWithAccessLevel / showNestedTypes /
        # showExtensions / showGenerics / relationships 均可在此覆盖（结构同全局 elements）

      # 跨 group 关系规则（默认全部关闭）
      crossGroupRelationships:
        inheritance: false
        association: false
        aggregation: false
        composition: false
        dependency: false
        singleLine:             # 跨 group 关系聚合为 group 间单行链接
          excludeSameGroup: true  # 同组内关系不受影响
          allGroups: true         # 任意跨 group 关系对只输出一条链接

    # ---------- 4. PlantUML skinparam 命令 (skinparamCommands) ----------
    # 追加到输出脚本末尾的 skinparam 命令，按需增删。
    skinparamCommands:
      - "skinparam shadow false"
      - "skinparam classWidth 120"
    """

    /// 将模板写入指定路径（原子写入）。
    /// - Parameter path: 目标文件路径。
    /// - Throws: 文件写入失败时抛出。
    static func write(to path: String) throws {
        try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
