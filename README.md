<div align="center">

# SwiftClassDiagram

从 Swift 源码生成 PlantUML 类图的开源命令行工具，附带本地 Web 控制台。

基于 [SwiftPlantUML](https://github.com/MarcoEidinger/SwiftPlantUML)（MIT）移植并深度增强。

![Platform](https://img.shields.io/badge/platform-macOS-2ea44f)
![Language](https://img.shields.io/badge/language-Swift%206-orange)
![License](https://img.shields.io/badge/license-MIT-blue)
![Version](https://img.shields.io/badge/version-1.0.0-blue)

</div>

---

## 目录

- [功能特性](#功能特性)
- [截图与体验](#截图与体验)
- [工作原理](#工作原理)
- [安装](#安装)
  - [方式一：Homebrew（推荐）](#方式一homebrew推荐)
  - [方式二：源码构建](#方式二源码构建)
- [快速开始](#快速开始)
- [命令行使用](#命令行使用)
  - [`classdiagram`：生成类图](#classdiagram生成类图)
  - [`serve`：本地 Web 控制台](#serve本地-web-控制台)
  - [`report`：复杂度与耦合度量报告](#report复杂度与耦合度量报告)
- [配置文件 `.swiftplantuml.yml`](#配置文件-swiftplantumlyml)
- [Web 控制台功能](#web-控制台功能)
- [常见问题 FAQ](#常见问题-faq)
- [致谢与许可](#致谢与许可)

---

## 功能特性

- **纯本地绘制，无任何在线 API**：使用 SourceKit 解析 Swift AST，图片由本地 `plantuml` + Graphviz 渲染，全程不联网，隐私安全。
- **类型识别覆盖全**：`class` / `struct` / `enum` / `protocol`，支持继承、组合、关联等关系推导（跨文件）。
- **YAML 配置驱动**：`.swiftplantuml.yml` 控制包含/排除、访问级别过滤、关系类型、分组与标签高亮。
- **内置输出清洗（`--cleanup`）**：自动移除编译器合成协议（如 `@unchecked Sendable` 幽灵节点）与多行成员，与 Web 预览保持一致的干净输出。
- **本地 Web 控制台（`serve`）**：浏览器内可视化编辑配置、实时预览、按 group 分图渲染、拖拽缩放、图片拷贝与保存。
- **度量报告（`report`）**：模块耦合矩阵 + 类复杂度排名，JSON / Markdown 两种输出。

## 截图与体验

```
# 在当前项目目录启动控制台后，浏览器访问 http://localhost:8080
swiftclassdiagram serve
```

![web-console](https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=macOS%20browser%20showing%20a%20dark%20web%20console%20for%20editing%20Swift%20class%20diagram%20configuration%2C%20left%20panel%20with%20YAML%20form%20fields%2C%20right%20panel%20with%20generated%20UML%20class%20diagram%20in%20plantuml%20style&image_size=landscape_16_9)

## 工作原理

```
Swift 源码
   │
   ▼
SourceKitten (SourceKit) ──► 解析 AST，提取类型声明与成员
   │
   ▼
SwiftClassDiagramKit ──► 按 .swiftplantuml.yml 过滤 → 构建 PlantUML 文本
   │
   ├──► CLI 输出（--output consoleOnly）或浏览器打开（--output browser）
   │
   ▼
PlantUML（本地 Java + Graphviz）──► SVG / PNG 类图
```

- **解析**：`SourceKittenFramework` 调用 SourceKit 获取完整声明结构（类型、继承、成员、访问级别）。
- **绘制**：直接调用本地 `plantuml`（优先解析 Homebrew 包装脚本直启 `java -DPLANTUML_LIMIT_SIZE=16384`，规避默认 4096 像素画布截断），渲染为 SVG。
- **预览**：`serve` 内置极简 HTTP 服务器 + 原生 HTML/CSS/JS 控制台，无需安装 Node 等任何前端运行时。

## 安装

### 方式一：Homebrew（推荐）

本仓库提供 Formula，公式从 GitHub Release 源码包构建：

```bash
brew tap LongXiangGuo/SwiftDiagram https://github.com/LongXiangGuo/SwiftDiagram.git
brew install swiftdiagram
```

> 构建依赖：macOS 13+、Xcode 命令行工具（`xcode-select --install`）、Swift 工具链。
> 图片渲染依赖（可选，仅在生成图片时使用）：`brew install plantuml openjdk graphviz`

### 方式二：源码构建

```bash
git clone https://github.com/LongXiangGuo/SwiftDiagram.git
cd SwiftDiagram
swift build -c release
# 二进制位于 .build/release/swiftclassdiagram，可复制到任意位置使用
```

## 快速开始

```bash
# 1. 进入你的 Swift 工程目录，编写配置（可选，默认自动发现）
cat > .swiftplantuml.yml <<'EOF'
elements:
  include:
    - type: class
    - type: struct
relationships:
  include:
    - type: inheritance
    - type: composition
EOF

# 2. 生成 PlantUML 脚本并打印到控制台
swiftclassdiagram classdiagram --output consoleOnly --cleanup

# 3. 或直接渲染并打开图片
swiftclassdiagram classdiagram --output browser

# 4. 或在浏览器中打开可视化控制台（推荐）
swiftclassdiagram serve
# 访问 http://localhost:8080
```

## 命令行使用

### `classdiagram`：生成类图

默认子命令，无子命令时直接执行。语法：

```bash
swiftclassdiagram classdiagram [options] [paths...]
```

| 选项 | 说明 |
| :--- | :--- |
| `--config <path>` | 自定义配置文件路径（默认搜索当前目录 `.swiftplantuml.yml`） |
| `--exclude <paths>` | 忽略的源文件/目录，优先级高于参数 |
| `--output <format>` | 输出格式：`browser`（默认，浏览器打开 HTML 预览）、`browserImageOnly`（仅渲染图片）、`consoleOnly`（打印 PlantUML 文本） |
| `--sdk <path>` | macOS SDK 路径，类型推断用，通常 `$(xcrun --show-sdk-path -sdk macosx)` |
| `--cleanup` | 应用内置输出清洗（移除幽灵类型链接、多行成员折叠） |
| `--verbose` | 输出详细日志 |
| `paths...` | 要分析的 Swift 文件或目录列表；为空则扫描当前目录 |

示例：

```bash
# 只分析 Sources 目录，输出清洗后的 PlantUML 文本
swiftclassdiagram classdiagram Sources --output consoleOnly --cleanup

# 忽略 Tests 目录，浏览器中打开类图
swiftclassdiagram classdiagram . --exclude Tests --output browser

# 指定 SDK 路径以正确解析类型推断（多平台复杂项目）
swiftclassdiagram classdiagram --sdk "$(xcrun --show-sdk-path -sdk macosx)" --output browser
```

### `serve`：本地 Web 控制台

启动一个本地 Web 服务，在浏览器中可视化编辑配置并实时预览类图：

```bash
swiftclassdiagram serve [--port <port>] [--config <path>]
```

| 选项 | 说明 |
| :--- | :--- |
| `-p, --port <port>` | 监听端口（默认 `8080`） |
| `--config <path>` | 配置文件路径（默认当前目录 `.swiftplantuml.yml`） |

示例：

```bash
swiftclassdiagram serve --port 9000
# Web console will listen on http://localhost:9000
```

### `report`：复杂度与耦合度量报告

输出模块耦合矩阵与类复杂度排名：

```bash
swiftclassdiagram report [--format json|markdown] [--top <n>] [options] [paths...]
```

| 选项 | 说明 |
| :--- | :--- |
| `--config <path>` | 自定义配置文件路径 |
| `-f, --format <format>` | 输出格式：`markdown`（默认）/ `json` |
| `--top <n>` | 复杂度排名展示条数（仅 markdown，默认 20） |
| `--sdk <path>` | macOS SDK 路径 |
| `--verbose` | 详细日志 |

示例：

```bash
# Markdown 表格报告
swiftclassdiagram report .

# JSON 机器可读报告
swiftclassdiagram report . --format json > report.json
```

### 其他

```bash
swiftclassdiagram version   # 显示版本号
swiftclassdiagram --help    # 查看全部子命令
```

## 配置文件 `.swiftplantuml.yml`

控制生成行为的核心文件，位于当前工作目录（或通过 `--config` 指定）：

```yaml
# 文件收集
files:
  include: ["**/*.swift"]       # 包含的源文件 glob
  exclude: [".build", "Tests"]  # 排除的目录/文件

# 元素过滤（绘制哪些类型）
elements:
  include:
    - type: class
    - type: struct
    - type: enum
    - type: protocol
  exclude:
    - type: class
      name: ".*Internal.*"
    - "@unchecked Sendable"     # 排除编译器合成协议幽灵节点

# 关系过滤（绘制哪些连线）
relationships:
  include:
    - type: inheritance
    - type: composition
    - type: aggregation
  exclude:
    - type: conformance

# 访问级别过滤
accessLevel: ["public", "internal"]

# 分组设置（Web 控制台按 group 分图）
groupSettings:
  defaultGroupName: "全部"
  groups:
    - name: "Core"
      tags: ["CoreModule"]
```

> 配置详细字段说明见 Web 控制台内置表单与 [Configuration.swift](Sources/SwiftClassDiagramKit/Configuration/Configuration.swift)。

## Web 控制台功能

| 功能 | 说明 |
| :--- | :--- |
| 配置可视化编辑 | 表单模式 / YAML 源码模式双入口，即时保存到 `.swiftplantuml.yml` |
| 实时预览 | 点击「预览」即时生成 PlantUML 文本并渲染 |
| 分组渲染 | 勾选「自动生成每个 group」后按 group 分多张图渲染，带渲染进度提示（共 N 个类 / 生成第 x 个 group / 生成全景图） |
| 拖拽与缩放 | 缩略图与 Lightbox 均支持全方向拖拽（👋 选中后拖动，Esc 取消）；缩放上限支持到 16px 以上字号 |
| 图片拷贝 / 保存 | 一键拷贝图片到剪贴板；保存为 `group名 + 时间戳.png`，保存路径 toast 提示 |
| 类型联想 | tag 输入自动补全源码中的类型名 |

## 常见问题 FAQ

**Q：为什么图片渲染不出来？**
A：图片渲染需要本地 PlantUML 环境，安装：`brew install plantuml openjdk graphviz`。

**Q：`serve` 提示资源找不到？**
A：使用 Homebrew 安装或 release 二进制时，Web 资源已随 SwiftPM 资源 bundle 打包，无需源码目录；请确认安装的是新版本（≥1.0.0）。

**Q：类图太大被截断？**
A：工具已注入 `-DPLANTUML_LIMIT_SIZE=16384` 提升画布上限；若仍不足可在 `serve` 中按 group 分图渲染。

**Q：支持 Linux / Windows 吗？**
A：解析依赖 SourceKit（macOS/Xcode 生态），当前仅支持 macOS。

## 致谢与许可

- 移植自 [SwiftPlantUML](https://github.com/MarcoEidinger/SwiftPlantUML)（MIT License），本项目在其基础上做了输出清洗、Web 控制台、度量报告等大量增强。
- 本项目源码以 [MIT License](LICENSE) 开源。
