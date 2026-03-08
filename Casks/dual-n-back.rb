cask "dual-n-back" do
  arch arm: "arm64", intel: "x86_64"

  version "1.0.0"
  sha256 arm: "420a61a33895a9542a1ed9be1001ad1db24e792bc018e782941bcb240df23a55",
         intel: "3b5171a83303c3b9d7dc716c709ae3475af8f29a8791fe65299996e5f4b36347"

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
