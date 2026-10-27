cask "dual-n-back" do
  arch arm: "arm64", intel: "x86_64"

  version "1.2.0"
  sha256 arm: "2b7b6744387abca16857960756c3473825e8db15fd26dc010aa86b53f3696760",
         intel: "ceded04e56f67cd93489ba43cae5bd58c9142f87278f85c5ababf249bc6fb317"

  url "https://github.com/eweinhoffer/dual-n-back/releases/download/v#{version}/Dual-N-Back-macOS-unsigned-#{arch}.zip"
  name "Dual N-Back"
  desc "Dual n-back working memory training app for macOS"
  homepage "https://github.com/eweinhoffer/dual-n-back"

  deprecate! date: "2026-10-26", because: :discontinued

  livecheck do
    skip "The macOS app is retired; 1.2.0 is the final release."
  end

  app "Dual N-Back.app"

  caveats <<~EOS
    The macOS app is retired and no longer receives updates or support.
    This cask installs the final unsigned 1.2.0 release.
    On first launch, macOS Gatekeeper may block it.
    If blocked, right-click the app and choose Open.
  EOS
end
