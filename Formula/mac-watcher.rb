class MacWatcher < Formula
  desc "Monitor Mac activity with email alerts when system wakes from sleep"
  homepage "https://github.com/ramanaraj7/mac-watcher"
  url "https://github.com/ramanaraj7/mac-watcher/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "850aad9e7c208dda3eadf7482ff25fc1ccdc3737345951d8783e1a8ed41df1be" # SHA256 of the GitHub release file
  license "MIT"
  
  depends_on "sleepwatcher"
  depends_on "jq"
  depends_on "imagesnap"
  # CoreLocationCLI is a cask and will be installed automatically by the setup script
  
  def install
    bin.install "bin/mac-watcher"
    
    share_dir = share/"mac-watcher"
    share_dir.install "share/mac-watcher/config.sh"
    share_dir.install "share/mac-watcher/monitor.sh"
    share_dir.install "share/mac-watcher/setup.sh"
    
    chmod 0755, share_dir/"config.sh"
    chmod 0755, share_dir/"monitor.sh"
    chmod 0755, share_dir/"setup.sh"
  end

  def post_install
    puts "Installing dependencies..."
    system "#{bin}/mac-watcher", "--dependencies"
  end
  
  def pre_uninstall
    # Stop sleepwatcher service if it's running
    system "brew", "services", "stop", "sleepwatcher" rescue nil
    
    # Remove configuration files
    system "rm", "-f", "#{ENV["HOME"]}/.wakeup"
    system "rm", "-f", "#{ENV["HOME"]}/.config/monitor.conf"
    
    # Remove any lingering symlinks
    system "rm", "-f", "/usr/local/bin/mac-watcher"
    
    puts "Removed Mac-Watcher configuration files and scripts."
  end

  def caveats
    <<~EOS
      To complete setup, please run:
        mac-watcher --setup
        mac-watcher --config (optional, to customize settings)
      
      Then start the sleepwatcher service:
        brew services start sleepwatcher
      
      To test functionality without waiting for a wake event:
        mac-watcher --test
      
      Required dependencies were automatically installed:
        - sleepwatcher (for wake detection)
        - jq (for JSON processing)
        - imagesnap (for webcam capture)
        - CoreLocationCLI (for location tracking) - attempted auto-install
      
      The setup process creates:
        - ~/.wakeup (wake detection script)
        - ~/.config/monitor.conf (default configuration)
      
      For more information, run:
        mac-watcher --instructions
      
      To completely uninstall and remove all configuration files:
        brew uninstall mac-watcher
    EOS
  end
  
  test do
    system "#{bin}/mac-watcher", "--help"
  end
end