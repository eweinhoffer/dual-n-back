cask "dual-n-back" do
  arch arm: "arm64", intel: "x86_64"

  version "0.0.2-test"
  sha256 arm: "f39a705618179eeaceb00ad5c9782a7bdb76d3aa72471a544e36da7eccf66424",
         intel: "4e11d666b8237ffc4994adb328c757ae0e6c87a5af9f0ccbfdb5834428a771da"

  url "https://github.com/eweinhoffer/dual-n-back/releases/download/v#{version}/Dual-N-Back-macOS-unsigned-#{arch}.zip"
  name "Dual N-Back"
  desc "Dual n-back working memory training app for macOS"
  homepage "https://github.com/eweinhoffer/dual-n-back"

  livecheck do
    url :homepage
    regex(/^v?(\d+(?:\.\d+)*(?:[-.][0-9A-Za-z]+)?)$/i)
    strategy :github_latest
  end

  app "Dual N-Back.app"

  caveats <<~EOS
    This cask currently installs an unsigned app bundle.
    On first launch, macOS Gatekeeper may block it.
    If blocked, right-click the app and choose Open.
  EOS
end
