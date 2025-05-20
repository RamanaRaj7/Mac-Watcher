class MacWatcher < Formula
  desc "Monitor Mac activity with email alerts when system wakes from sleep"
  homepage "https://github.com/ramanaraj7/Mac-Watcher"
  url "https://github.com/ramanaraj7/Mac-Watcher/archive/refs/tags/v1.0.2.tar.gz"
  sha256 "7cb777faf8c8f67acde1bffe7a930e955c46c0fa775ea4c9d004b47fc3be8f5a"
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
