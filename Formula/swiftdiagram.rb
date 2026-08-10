class Swiftdiagram < Formula
  desc "Generate PlantUML class diagrams from Swift source code with a local web console"
  homepage "https://github.com/LongXiangGuo/SwiftDiagram"
  url "https://github.com/LongXiangGuo/SwiftDiagram/archive/refs/tags/v1.0.5.tar.gz"
  sha256 "d2d80cbdcdadb02a4574fefb55b187f234a65ea8c806e3e0c04d9a881ffc5c96"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["13.0"]

  def install
    # --disable-sandbox: SwiftPM 需要在构建期拉取 SPM 依赖（SourceKitten 等）
    system "swift", "build", "-c", "release", "--disable-sandbox", "--product", "swiftclassdiagram"
    bin.install ".build/release/swiftclassdiagram"
    # Web 控制台静态资源随 SPM 资源 bundle 分发，须与二进制同目录（Bundle.module 经 Bundle.main.resourceURL 定位）
    Dir[".build/release/*.bundle"].each { |bundle| bin.install bundle }
  end

  test do
    assert_match "1.0.5", shell_output("#{bin}/swiftclassdiagram --version")
  end

  def caveats
    <<~EOS
      SwiftClassDiagram #{version} 安装完成。

      环境要求：
        - macOS 13+（Apple Silicon / Intel 均可）
        - Xcode 命令行工具：xcode-select --install
        - Swift 工具链（随 CommandLineTools 提供）

      图片渲染依赖（可选，仅 --output browser / serve 预览时使用）：
        brew install plantuml openjdk graphviz

      快速上手：
        swiftclassdiagram --help       # 查看全部子命令与用法
        swiftclassdiagram --version    # 查看当前版本（#{version}）
        swiftclassdiagram serve        # 启动本地 Web 控制台，浏览器访问 http://localhost:8080
    EOS
  end
end
