class MacWatcher < Formula
  desc "Monitor Mac activity with email alerts when system wakes from sleep"
  homepage "https://github.com/ramanaraj7/mac-watcher"
  url "https://github.com/ramanaraj7/mac-watcher/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "a53d8bf8a8c3c18471b5a08bc1991bd3561ab398c7a409c8a170b8023c891228" # SHA256 of the GitHub release file
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
  
  # Note about manual cleanup
  def pre_uninstall
    puts "\n===== MAC-WATCHER UNINSTALL INFORMATION ====="
    puts "Mac-Watcher has been uninstalled, but configuration files remain."
    puts "To completely remove all related files, please run the following commands:"
    puts ""
    puts "  # Stop the sleepwatcher service"
    puts "  brew services stop sleepwatcher"
    puts ""
    puts "  # Remove configuration files"
    puts "  rm -f ~/.wakeup"
    puts "  rm -f ~/.config/monitor.conf"
    puts ""
    puts "  # Remove symlinks (if any)"
    puts "  rm -f /usr/local/bin/mac-watcher"
    puts "============================================="
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
      
      To completely uninstall Mac-Watcher:
        # Uninstall the formula
        brew uninstall ramanaraj7/tap/mac-watcher
        
        # Stop the sleepwatcher service
        brew services stop sleepwatcher
        
        # Manually remove all configuration files
        rm -f ~/.wakeup
        rm -f ~/.config/monitor.conf
    EOS
  end
  
  test do
    system "#{bin}/mac-watcher", "--help"
  end
end 