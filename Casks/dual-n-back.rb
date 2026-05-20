cask "dual-n-back" do
  arch arm: "arm64", intel: "x86_64"

  version "1.1.1"
  sha256 arm: "80b81942505021c2321af0255c653fc0a3d377c027601eef62cd6a1eaa0f2f76",
         intel: "ec0f1415f33296d5d4a17664224e7bee5856cdfea44efa306b16ad5fe92b470d"

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
