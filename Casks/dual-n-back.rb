cask "dual-n-back" do
  arch arm: "arm64", intel: "x86_64"

  version :latest
  sha256 :no_check

  url "https://github.com/eweinhoffer/dual-n-back/releases/latest/download/Dual-N-Back-macOS-unsigned-#{arch}.zip"
  name "Dual N-Back"
  desc "Dual n-back working memory training app for macOS"
  homepage "https://github.com/eweinhoffer/dual-n-back"

  app "Dual N-Back.app"

  caveats <<~EOS
    This cask currently installs an unsigned app bundle.
    On first launch, macOS Gatekeeper may block it.
    If blocked, right-click the app and choose Open.
  EOS
end
