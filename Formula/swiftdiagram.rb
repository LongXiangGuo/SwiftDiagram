class Swiftdiagram < Formula
  desc "Generate PlantUML class diagrams from Swift source code with a local web console"
  homepage "https://github.com/LongXiangGuo/SwiftDiagram"
  url "https://github.com/LongXiangGuo/SwiftDiagram/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "79e90f0dd65f57091ea47e13f994fd9baf69e3291498735482666f6f9aa475fe"
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
    assert_match "1.0.0", shell_output("#{bin}/swiftclassdiagram --version")
  end
end
