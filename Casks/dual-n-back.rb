cask "dual-n-back" do
  arch arm: "arm64", intel: "x86_64"

  version "1.2.0"
  sha256 arm: "2b7b6744387abca16857960756c3473825e8db15fd26dc010aa86b53f3696760",
         intel: "ceded04e56f67cd93489ba43cae5bd58c9142f87278f85c5ababf249bc6fb317"

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
