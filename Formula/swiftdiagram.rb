class Swiftdiagram < Formula
  desc "Generate PlantUML class diagrams from Swift source code with a local web console"
  homepage "https://github.com/LongXiangGuo/SwiftDiagram"
  url "https://github.com/LongXiangGuo/SwiftDiagram/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_SHA256"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["13.0"]

  def install
    # --disable-sandbox: SwiftPM 需要在构建期拉取 SPM 依赖（SourceKitten 等）
    system "swift", "build", "-c", "release", "--disable-sandbox", "--product", "swiftclassdiagram"
    bin.install ".build/release/swiftclassdiagram"
  end

  test do
    assert_match "1.0.0", shell_output("#{bin}/swiftclassdiagram version")
  end
end
