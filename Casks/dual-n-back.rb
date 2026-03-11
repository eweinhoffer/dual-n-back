cask "dual-n-back" do
  arch arm: "arm64", intel: "x86_64"

  version "1.1.0"
  sha256 arm: "f521068a9923b1ea0a3db1145798fd4aceffff3689d3dfdf79725adc67061c1e",
         intel: "965b46b042e24613cc7dc7b0a4e039216915dd1d0931bd4e89f162f165633b36"

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
