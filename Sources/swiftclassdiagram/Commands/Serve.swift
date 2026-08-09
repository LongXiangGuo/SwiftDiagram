import ArgumentParser
import Foundation
import SwiftClassDiagramKit
import Yams

extension SwiftClassDiagram {
    /// `swiftclassdiagram serve` —— 启动本地 Web 控制台，可视化编辑 `.swiftplantuml.yml` 并预览类图。
    struct Serve: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "serve",
            abstract: "Start a local web console to edit .swiftplantuml.yml and preview the class diagram",
            helpNames: [.short, .long]
        )

        @Option(name: .shortAndLong, help: "Port to listen on")
        var port: UInt16 = 8080

        @Option(help: "Path to configuration file (default: .swiftplantuml.yml in current directory)")
        var config: String?

        func run() throws {
            let configPath = config ?? ".swiftplantuml.yml"
            let console = WebConsole(configPath: configPath)

            let server = try MiniHTTPServer(port: port) { request in
                switch (request.method, request.path) {
                case ("GET", "/"):
                    return console.indexHTML()
                case ("GET", "/console.css"):
                    return console.staticFile(name: "console.css", contentType: "text/css; charset=utf-8")
                case ("GET", "/console.js"):
                    return console.staticFile(name: "console.js", contentType: "application/javascript; charset=utf-8")
                case ("GET", "/api/config"):
                    // JSON 配置（表单模式）
                    return console.configJSON()
                case ("GET", "/api/config-text"):
                    // YAML 文本（源码模式）
                    return console.currentConfig()
                case ("GET", "/api/dirs"):
                    // 候选目录列表（group folder 下拉 / 默认 group 列表）
                    return console.candidateDirs()
                case ("GET", "/api/types"):
                    // 类型名列表（tag 输入联想提示）
                    return console.typeCandidates()
                case ("POST", "/api/config"):
                    // JSON 配置 → YAML 保存（表单模式）
                    return console.saveConfigJSON(body: request.body)
                case ("POST", "/api/save"):
                    return console.save(yamlBody: request.body)
                case ("POST", "/api/preview"):
                    return console.preview(yamlBody: request.body)
                case ("POST", "/api/preview-json"):
                    return console.previewJSON(body: request.body)
                case ("POST", "/api/image"):
                    // 用本地 plantuml 渲染 PNG
                    return console.renderImage(body: request.body)
                case ("POST", "/api/images"):
                    // 按启用 group 分多张渲染 PNG
                    return console.renderImages(body: request.body)
                case ("POST", "/api/render"):
                    // 异步渲染任务（前端轮询进度）
                    return console.startRenderTask(body: request.body, autoGroup: request.queryValue("autoGroup") == "1")
                case ("GET", "/api/render/progress"):
                    return console.renderProgress(task: request.queryValue("task") ?? "")
                default:
                    return .notFound
                }
            }
            Logger.shared.info("Web console will listen on http://localhost:\(port) (config: \(configPath))")
            server.startAndWait()
        }
    }
}

extension MiniHTTPServer.Request {
    /// 读取查询参数（如 `/api/render?autoGroup=1` 的 `autoGroup`）。
    func queryValue(_ name: String) -> String? {
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, String(kv[0]) == name {
                return String(kv[1])
            }
        }
        return nil
    }
}

/// Web 控制台后端逻辑：配置读写与 PlantUML 预览。
final class WebConsole {
    private let configPath: String

    init(configPath: String) {
        self.configPath = configPath
    }

    // MARK: - 读取当前配置

    /// GET /api/config：返回当前 `.swiftplantuml.yml` 内容。
    func currentConfig() -> MiniHTTPServer.Response {
        let url = URL(fileURLWithPath: configPath)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Cannot read \(configPath) (not found?)"))
        }
        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return .json("{\"ok\":true,\"path\":\"\(configPath)\",\"content\":\"\(escaped)\"}")
    }

    // MARK: - 读取当前配置（JSON，表单模式）

    /// GET /api/config：返回结构化 JSON 配置（YAML → 解码 → JSON）。
    func configJSON() -> MiniHTTPServer.Response {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Cannot read \(configPath) (not found?)"))
        }
        do {
            let config = try YAMLDecoder().decode(Configuration.self, from: content)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let json = String(data: try encoder.encode(config), encoding: .utf8) ?? "{}"
            return .json("{\"ok\":true,\"path\":\"\(configPath)\",\"config\":\(json)}")
        } catch {
            return .json(apiResponse(ok: false, message: "Invalid YAML: \(error.localizedDescription)"))
        }
    }

    // MARK: - 保存配置（JSON，表单模式）

    /// POST /api/config：接收 JSON 配置，转 YAML 写回 `.swiftplantuml.yml`。
    func saveConfigJSON(body: Data) -> MiniHTTPServer.Response {
        guard let jsonText = String(data: body, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Request body is not UTF-8 text"))
        }
        do {
            let config = try JSONDecoder().decode(Configuration.self, from: Data(jsonText.utf8))
            let yaml = try YAMLEncoder().encode(config)
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)
            return .json(apiResponse(ok: true, message: "Saved to \(configPath)"))
        } catch {
            return .json(apiResponse(ok: false, message: "Invalid config JSON: \(error.localizedDescription)"))
        }
    }

    // MARK: - 预览（JSON，表单模式）

    /// POST /api/preview-json：按 JSON 配置生成 PlantUML 文本。
    func previewJSON(body: Data) -> MiniHTTPServer.Response {
        guard let jsonText = String(data: body, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Request body is not UTF-8 text"))
        }
        do {
            let config = try JSONDecoder().decode(Configuration.self, from: Data(jsonText.utf8))
            return preview(configuration: config)
        } catch {
            return .json(apiResponse(ok: false, message: "Invalid config JSON: \(error.localizedDescription)"))
        }
    }

    // MARK: - 保存配置（YAML 文本）

    /// POST /api/save：将 YAML 文本写回 `.swiftplantuml.yml`。
    func save(yamlBody: Data) -> MiniHTTPServer.Response {
        guard let text = String(data: yamlBody, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Request body is not UTF-8 text"))
        }
        // 写入前先校验 YAML 可解析，避免保存坏配置
        do {
            _ = try YAMLDecoder().decode(Configuration.self, from: text)
        } catch {
            return .json(apiResponse(ok: false, message: "Invalid YAML: \(error.localizedDescription)"))
        }
        do {
            try text.write(toFile: configPath, atomically: true, encoding: .utf8)
            return .json(apiResponse(ok: true, message: "Saved to \(configPath)"))
        } catch {
            return .json(apiResponse(ok: false, message: "Cannot write \(configPath): \(error.localizedDescription)"))
        }
    }

    // MARK: - 预览（YAML 文本）

    /// POST /api/preview：按请求体中的 YAML 配置生成 PlantUML 文本。
    func preview(yamlBody: Data) -> MiniHTTPServer.Response {
        guard let text = String(data: yamlBody, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Request body is not UTF-8 text"))
        }
        let configuration: Configuration
        do {
            configuration = try YAMLDecoder().decode(Configuration.self, from: text)
        } catch {
            return .json(apiResponse(ok: false, message: "Invalid YAML: \(error.localizedDescription)"))
        }
        return preview(configuration: configuration)
    }

    // MARK: - 候选目录（group folder 下拉 / 默认 group 列表）

    /// GET /api/dirs：返回当前目录一级子目录（供 group folder 下拉选择与默认 group 列表填充）。
    func candidateDirs() -> MiniHTTPServer.Response {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        guard let entries = try? fm.contentsOfDirectory(
            at: cwd,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .json(apiResponse(ok: false, message: "Cannot list directory \(cwd.path)"))
        }
        let dirs = entries.compactMap { url -> String? in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir, !url.lastPathComponent.hasPrefix(".") else { return nil }
            return url.lastPathComponent
        }.sorted()
        let items = dirs.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: ",")
        return .json("{\"ok\":true,\"dirs\":[\(items)]}")
    }

    // MARK: - 静态资源（HTML / CSS / JS 从本地文件加载）

    /// Web 控制台静态资源目录（`Sources/swiftclassdiagram/WebResources`）。
    ///
    /// 查找顺序（全部命中即返回）：
    /// 1. 真实二进制同目录的 SPM 资源 bundle（brew install / 拷贝安装场景，symlink 解析到 Cellar/bin）
    /// 2. `Bundle.main` 同目录的 SPM 资源 bundle（直接通过 `/opt/homebrew/bin` symlink 调用时）
    /// 3. 源码运行（swift run / swift build）兜底：`#filePath` 定位源码目录
    private enum WebResources {
        static let bundleName = "SwiftClassDiagram_swiftclassdiagram"

        static var directory: String {
            let fm = FileManager.default
            for candidate in candidatePaths where fm.fileExists(atPath: candidate) {
                return candidate
            }
            // 源码运行兜底：#filePath 定位源码目录
            return URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Commands/
                .deletingLastPathComponent() // swiftclassdiagram/
                .appendingPathComponent("WebResources").path
        }

        /// 候选目录列表。
        private static var candidatePaths: [String] {
            var paths: [String] = []
            if let binaryDir = executableDirectoryURL {
                paths.append(bundleWebResourcesURL(in: binaryDir))
            }
            if let mainResourceURL = Bundle.main.resourceURL {
                paths.append(bundleWebResourcesURL(in: mainResourceURL))
            }
            return paths
        }

        /// 在指定目录下定位 `bundleName.bundle/WebResources`。
        private static func bundleWebResourcesURL(in directory: URL) -> String {
            directory
                .appendingPathComponent("\(bundleName).bundle")
                .appendingPathComponent("WebResources").path
        }

        /// 真实二进制所在目录（解析 symlink，如 `/opt/homebrew/bin/swiftclassdiagram` → `Cellar/.../bin`）。
        private static var executableDirectoryURL: URL? {
            guard let arg0 = CommandLine.arguments.first else { return nil }
            return URL(fileURLWithPath: arg0)
                .resolvingSymlinksInPath()
                .deletingLastPathComponent()
        }
    }

    /// GET /：控制台首页（从本地 `console.html` 读取，样式与逻辑分离为 css / js 文件）。
    func indexHTML() -> MiniHTTPServer.Response {
        staticFile(name: "console.html", contentType: "text/html; charset=utf-8")
    }

    /// GET /console.css / /console.js：静态资源。
    func staticFile(name: String, contentType: String) -> MiniHTTPServer.Response {
        let path = WebResources.directory + "/" + name
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Resource \(name) not found at \(path)"))
        }
        return .data(Data(content.utf8), contentType: contentType)
    }

    // MARK: - 类型名联想（tag 输入）

    /// GET /api/types：返回当前 include 源文件中的类型名（类/结构体/枚举/协议），供 tag 输入联想。
    func typeCandidates() -> MiniHTTPServer.Response {
        let directory = FileManager.default.currentDirectoryPath
        var filesOptions = FileOptions()
        if let content = try? String(contentsOfFile: configPath, encoding: .utf8),
           let config = try? YAMLDecoder().decode(Configuration.self, from: content) {
            filesOptions = config.files
        }
        let files = FileCollector().getFiles(for: [], in: directory, honoring: filesOptions)
        let regex = try? NSRegularExpression(
            pattern: #"\b(?:class|struct|enum|protocol)\s+([A-Z][A-Za-z0-9_]*)"#
        )
        var names = Set<String>()
        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            guard let regex else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                names.insert(String(text[r]))
            }
        }
        let sorted = names.sorted()
        let items = sorted.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: ",")
        return .json("{\"ok\":true,\"types\":[\(items)]}")
    }

    // MARK: - PlantUML 图片渲染（本地 plantuml）

    /// 用本地 plantuml 渲染 PlantUML 文本为 SVG。成功时 `data` 非空，失败时 `error` 非空。
    private func renderPlantUML(_ text: String, timeout: TimeInterval = 30) -> (data: Data?, error: String?) {
        let process = Process()
        let launcher = PlantUMLRunner.launchCommand()
        process.executableURL = URL(fileURLWithPath: launcher.executableURL)
        process.arguments = launcher.arguments + ["-tsvg", "-pipe"]
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        var outData = Data()
        var errData = Data()
        stdout.fileHandleForReading.readabilityHandler = { outData.append($0.availableData) }
        stderr.fileHandleForReading.readabilityHandler = { errData.append($0.availableData) }

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()
            try stdin.fileHandleForWriting.write(contentsOf: Data(text.utf8))
            try stdin.fileHandleForWriting.close()
        } catch {
            return (nil, "Cannot run plantuml: \(error.localizedDescription)")
        }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return (nil, "plantuml render timeout (\(Int(timeout))s)")
        }
        if process.terminationStatus != 0 {
            let err = String(data: errData, encoding: .utf8) ?? "unknown error"
            return (nil, "plantuml failed: \(err)")
        }
        guard !outData.isEmpty else {
            return (nil, "plantuml produced empty output")
        }
        return (outData, nil)
    }

    /// POST /api/image：用本地 `plantuml -pipe` 将 PlantUML 文本渲染为 SVG。
    func renderImage(body: Data) -> MiniHTTPServer.Response {
        guard let text = String(data: body, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Request body is not UTF-8 text"))
        }
        let result = renderPlantUML(text)
        if let svg = result.data {
            return .data(svg, contentType: "image/svg+xml")
        }
        return .json(apiResponse(ok: false, message: result.error ?? "render failed"))
    }

    /// POST /api/images：按启用 group 分多张渲染 SVG（「全部」+ 每个启用 group 各一张）。
    /// 入参：表单模式为 JSON 配置，源码模式为 YAML 文本。返回 base64 SVG 数组。
    func renderImages(body: Data) -> MiniHTTPServer.Response {
        guard let text = String(data: body, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Request body is not UTF-8 text"))
        }
        let configuration: Configuration
        do {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                configuration = try JSONDecoder().decode(Configuration.self, from: Data(text.utf8))
            } else {
                configuration = try YAMLDecoder().decode(Configuration.self, from: text)
            }
        } catch {
            return .json(apiResponse(ok: false, message: "Invalid config: \(error.localizedDescription)"))
        }

        let generator = ClassDiagramGenerator()
        let directory = FileManager.default.currentDirectoryPath
        let files = FileCollector().getFiles(for: [], in: directory, honoring: configuration.files)

        var parts: [String] = []

        // 「全部」图
        let fullPresenter = CapturePresenter()
        generator.generate(for: files.map(\.path), with: configuration, presentedBy: fullPresenter)
        appendImagePart(&parts, title: "全部", scriptText: fullPresenter.scriptText, render: { renderPlantUML($0) })

        // 每个启用 group 一张
        for group in configuration.groupSettings.enabledGroups {
            let presenter = CapturePresenter()
            generator.generate(for: files.map(\.path), with: configuration, groupFilter: group.name, presentedBy: presenter)
            appendImagePart(&parts, title: group.name, scriptText: presenter.scriptText, render: { renderPlantUML($0) })
        }

        return .json("{\"ok\":true,\"images\":[\(parts.joined(separator: ","))]}")
    }

    // MARK: - 异步渲染任务（进度推送）

    /// POST /api/render：创建异步渲染任务并立即返回 taskId（前端轮询 /api/render/progress）。
    /// 入参同 /api/images（JSON 配置或 YAML 文本）；`autoGroup=false` 时仅渲染「全部」一张。
    func startRenderTask(body: Data, autoGroup: Bool) -> MiniHTTPServer.Response {
        guard let text = String(data: body, encoding: .utf8) else {
            return .json(apiResponse(ok: false, message: "Request body is not UTF-8 text"))
        }
        let configuration: Configuration
        do {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                configuration = try JSONDecoder().decode(Configuration.self, from: Data(text.utf8))
            } else {
                configuration = try YAMLDecoder().decode(Configuration.self, from: text)
            }
        } catch {
            return .json(apiResponse(ok: false, message: "Invalid config: \(error.localizedDescription)"))
        }

        let titles = autoGroup ? (["全部"] + configuration.groupSettings.enabledGroups.map(\.name)) : ["全部"]
        let taskID = RenderTaskCenter.shared.create(titles: titles)

        // 先统计类型数量供前端提示「共 N 个类」
        let directory = FileManager.default.currentDirectoryPath
        let files = FileCollector().getFiles(for: [], in: directory, honoring: configuration.files)
        let typeCount = countTypes(in: files)

        DispatchQueue.global().async { [weak self] in
            self?.runRenderTask(taskID: taskID, configuration: configuration, autoGroup: autoGroup)
        }
        return .json("{\"ok\":true,\"task\":\"\(taskID)\",\"types\":\(typeCount),\"total\":\(titles.count)}")
    }

    /// GET /api/render/progress：返回任务进度；完成后直接携带 images。
    func renderProgress(task taskID: String) -> MiniHTTPServer.Response {
        guard let snap = RenderTaskCenter.shared.snapshot(taskID) else {
            return .json(apiResponse(ok: false, message: "Task not found"))
        }
        if let images = snap.images {
            return .json("{\"ok\":true,\"finished\":true,\"images\":[\(images.joined(separator: ","))]}")
        }
        if let error = snap.error {
            return .json("{\"ok\":true,\"finished\":true,\"error\":\"\(error.replacingOccurrences(of: "\"", with: "\\\""))\"}")
        }
        let phase = snap.phase.replacingOccurrences(of: "\"", with: "\\\"")
        return .json("{\"ok\":true,\"finished\":false,\"phase\":\"\(phase)\",\"done\":\(snap.done),\"total\":\(snap.titles.count)}")
    }

    /// 在后台线程逐张渲染任务图，并更新进度。先全景图，再各 group。
    private func runRenderTask(taskID: String, configuration: Configuration, autoGroup: Bool) {
        let center = RenderTaskCenter.shared
        let directory = FileManager.default.currentDirectoryPath
        let files = FileCollector().getFiles(for: [], in: directory, honoring: configuration.files)
        let titles = autoGroup ? (["全部"] + configuration.groupSettings.enabledGroups.map(\.name)) : ["全部"]
        let generator = ClassDiagramGenerator()

        var parts: [String] = []
        for (index, title) in titles.enumerated() {
            let groupFilter = title == "全部" ? nil : title
            center.updatePhase(taskID, "正在渲染：\(title)（\(index + 1)/\(titles.count)）")
            let presenter = CapturePresenter()
            generator.generate(for: files.map(\.path), with: configuration, groupFilter: groupFilter, presentedBy: presenter)
            appendImagePart(&parts, title: title, scriptText: presenter.scriptText, render: { renderPlantUML($0) })
            center.markDone(taskID, done: index + 1)
        }
        center.finish(taskID, images: parts)
    }

    /// 统计源文件中的类型声明数量（class/struct/enum/protocol），用于进度提示。
    private func countTypes(in files: [URL]) -> Int {
        guard let regex = try? NSRegularExpression(pattern: #"\b(?:class|struct|enum|protocol)\s+[A-Z][A-Za-z0-9_]*"#) else { return 0 }
        var count = 0
        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            count += regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
        }
        return count
    }

    /// 渲染一张图并追加 JSON 片段；失败时带 `error` 标记。
    private func appendImagePart(_ parts: inout [String], title: String, scriptText: String, render: (String) -> (data: Data?, error: String?)) {
        let escapedTitle = title.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        if let svg = render(scriptText).data {
            parts.append("{\"title\":\"\(escapedTitle)\",\"data\":\"\(svg.base64EncodedString())\"}")
        } else {
            parts.append("{\"title\":\"\(escapedTitle)\",\"error\":true}")
        }
    }

    /// 按配置生成 PlantUML 文本（YAML / JSON 两条入口共用）。
    private func preview(configuration: Configuration) -> MiniHTTPServer.Response {
        let generator = ClassDiagramGenerator()
        let directory = FileManager.default.currentDirectoryPath
        let files = FileCollector().getFiles(for: [], in: directory, honoring: configuration.files)

        // generate 内部通过 semaphore 同步等待 presenter 完成
        let presenter = CapturePresenter()
        generator.generate(for: files.map(\.path), with: configuration, presentedBy: presenter)

        let escaped = presenter.scriptText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return .json("{\"ok\":true,\"files\":\(files.count),\"script\":\"\(escaped)\"}")
    }

    private func apiResponse(ok: Bool, message: String) -> String {
        "{\"ok\":\(ok),\"message\":\"\(message.replacingOccurrences(of: "\"", with: "\\\""))\"}"
    }
}

/// PlantUML 运行环境定位。
///
/// Homebrew 的 `plantuml` 包装脚本把用户参数放在 `-jar` 之后，无法注入 JVM 系统属性
/// （`-D` 必须位于 `-jar` 之前才生效）。因此解析脚本提取 java 与 jar 路径，
/// 直启 `java -DPLANTUML_LIMIT_SIZE=…`，规避 PlantUML 默认 4096 像素的画布截断。
private enum PlantUMLRunner {
    /// 画布上限（像素）。超出该值的宽/高会被 PlantUML 直接截断，大型类图默认 4096 不够。
    static let limitSize = 16384

    /// 返回启动命令（可执行文件路径 + 参数，不含输出格式参数）。
    static func launchCommand() -> (executableURL: String, arguments: [String]) {
        if let parsed = parseHomebrewLauncher() {
            return parsed
        }
        return ("/usr/bin/env", ["plantuml"])
    }

    /// 解析 `plantuml` 包装脚本，提取 java 与 jar 路径并构造带 LIMIT_SIZE 的命令。
    private static func parseHomebrewLauncher() -> (executableURL: String, arguments: [String])? {
        let candidates = ["/opt/homebrew/bin/plantuml", "/usr/local/bin/plantuml"]
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }),
              let script = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        guard let java = firstMatch("exec\\s+\"([^\"]+)\"", in: script),
              let jar = firstMatch("-jar\\s+(\\S+)", in: script) else {
            return nil
        }
        return (java, ["-DPLANTUML_LIMIT_SIZE=\(limitSize)", "-Djava.awt.headless=true", "-jar", jar])
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}

/// 异步图片渲染任务中心：创建任务、更新进度，供前端轮询查询。
final class RenderTaskCenter {
    static let shared = RenderTaskCenter()

    private struct Task {
        let titles: [String]
        var phase: String
        var done: Int
        var images: [String]?
        var error: String?
    }

    private let lock = NSLock()
    private var tasks: [String: Task] = [:]
    private var order: [String] = []

    /// 创建任务并返回任务 id。最多保留最近 10 个任务，防止内存膨胀。
    func create(titles: [String]) -> String {
        let id = UUID().uuidString
        lock.lock(); defer { lock.unlock() }
        order.append(id)
        if order.count > 10 {
            let old = order.removeFirst()
            tasks.removeValue(forKey: old)
        }
        tasks[id] = Task(titles: titles, phase: "准备中", done: 0, images: nil, error: nil)
        return id
    }

    func updatePhase(_ id: String, _ phase: String) {
        lock.lock(); defer { lock.unlock() }
        guard tasks[id] != nil else { return }
        tasks[id]?.phase = phase
    }

    func markDone(_ id: String, done: Int) {
        lock.lock(); defer { lock.unlock() }
        guard tasks[id] != nil else { return }
        tasks[id]?.done = done
    }

    func finish(_ id: String, images: [String]) {
        lock.lock(); defer { lock.unlock() }
        guard tasks[id] != nil else { return }
        tasks[id]?.images = images
        tasks[id]?.phase = "完成"
    }

    func fail(_ id: String, message: String) {
        lock.lock(); defer { lock.unlock() }
        guard tasks[id] != nil else { return }
        tasks[id]?.error = message
        tasks[id]?.phase = "失败"
    }

    /// 任务快照。
    func snapshot(_ id: String) -> (titles: [String], phase: String, done: Int, images: [String]?, error: String?)? {
        lock.lock(); defer { lock.unlock() }
        guard let t = tasks[id] else { return nil }
        return (t.titles, t.phase, t.done, t.images, t.error)
    }
}

/// 捕获生成的 PlantUML 脚本文本的 Presenter。
///
/// 与 CLI 一致地先经 `OutputCleaner` 清洗（删除编译器合成协议 / 幽灵类型链接行，
/// 如 `"@unchecked Sendable" <|-- Foo`），保证 Web 预览与 CLI 输出一致。
final class CapturePresenter: PlantUMLPresenting {
    private(set) var scriptText: String = ""

    func present(script: PlantUMLScript, completionHandler: @escaping () -> Void) {
        scriptText = OutputCleaner.clean(script.text)
        completionHandler()
    }
}
