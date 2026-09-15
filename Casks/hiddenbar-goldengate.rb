# Hidden Bar (Golden Gate fork) - macOS 27 build
cask "hiddenbar-goldengate" do
  version :latest
  sha256 :no_check

  url "https://github.com/xvoland/hidden/releases/latest/download/Hidden%20Bar.app.zip"
  name "Hidden Bar (Golden Gate fork)"
  homepage "https://github.com/xvoland/hidden"

  app "Hidden Bar.app"
end
