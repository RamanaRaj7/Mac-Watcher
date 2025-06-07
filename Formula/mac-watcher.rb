class MacWatcher < Formula
  desc "Monitor Mac activity with email alerts when system wakes from sleep"
  homepage "https://github.com/ramanaraj7/Mac-Watcher"
  url "https://github.com/RamanaRaj7/Mac-Watcher/archive/refs/tags/v1.0.4.tar.gz"
  sha256 "6430a095d6a3a60bd24570d9564e6e9eb51841f68de4a3a861c06986e390ea90"
  license "MIT"

  depends_on :macos
  depends_on "coreutils"
  depends_on "imagesnap"
  depends_on "jq"
  depends_on "sleepwatcher"

  def install
    bin.install "bin/mac-watcher"
    pkgshare.install "share/mac-watcher/config.sh"
    pkgshare.install "share/mac-watcher/monitor.sh"
    pkgshare.install "share/mac-watcher/setup.sh"
    chmod 0755, pkgshare/"config.sh"
    chmod 0755, pkgshare/"monitor.sh"
    chmod 0755, pkgshare/"setup.sh"
  end

  def caveats
    <<~EOS
      To complete setup, run:
        mac-watcher --setup
        mac-watcher --config (optional, to customize settings)
        mac-watcher --dependencies (to check/install required dependencies)

      Then start the sleepwatcher service:
        brew services start sleepwatcher

      To test functionality without waiting for a wake event:
        mac-watcher --test

      The setup process creates these user files:
        ~/.wakeup (wake detection script)
        ~/.config/monitor.conf (default configuration)
    EOS
  end

  test do
    system bin/"mac-watcher", "--help"
  end
end
