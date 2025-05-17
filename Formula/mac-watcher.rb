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
  
  # Helper method to check if files exist
  def self.check_file_exists(file_path)
    File.exist?(file_path) ? "EXISTS" : "NOT FOUND"
  end
  
  # Standard pre_uninstall hook
  def pre_uninstall
    require "fileutils"
    
    # Log before cleanup
    home = ENV["HOME"]
    
    puts "===== MAC-WATCHER UNINSTALL DIAGNOSTIC ====="
    puts "HOME: #{home}"
    puts "Config files before cleanup:"
    puts "  .wakeup: #{self.class.check_file_exists("#{home}/.wakeup")}"
    puts "  .config/monitor.conf: #{self.class.check_file_exists("#{home}/.config/monitor.conf")}"
    puts "  .config/mac-watcher: #{self.class.check_file_exists("#{home}/.config/mac-watcher")}"
    puts "============================================="
    
    # Stop sleepwatcher service if it's running
    system "brew", "services", "stop", "sleepwatcher" rescue nil
    
    # Remove configuration files - expand HOME variable to ensure it works
    FileUtils.rm_f("#{home}/.wakeup")
    FileUtils.rm_f("#{home}/.config/monitor.conf")
    FileUtils.rm_rf("#{home}/.config/mac-watcher")
    
    # Remove any lingering symlinks
    FileUtils.rm_f("/usr/local/bin/mac-watcher")
    
    # Log after cleanup
    puts "Config files after cleanup:"
    puts "  .wakeup: #{self.class.check_file_exists("#{home}/.wakeup")}"
    puts "  .config/monitor.conf: #{self.class.check_file_exists("#{home}/.config/monitor.conf")}"
    puts "  .config/mac-watcher: #{self.class.check_file_exists("#{home}/.config/mac-watcher")}"
    puts "============================================="
  end
  
  # Add a more robust uninstall hook as a backup
  def post_uninstall
    require "fileutils"
    
    # This is a backup to ensure cleanup happens
    home = ENV["HOME"]
    
    # Log before post-uninstall cleanup
    puts "\n===== MAC-WATCHER POST-UNINSTALL DIAGNOSTIC ====="
    puts "HOME: #{home}"
    puts "Config files before post-uninstall cleanup:"
    puts "  .wakeup: #{self.class.check_file_exists("#{home}/.wakeup")}"
    puts "  .config/monitor.conf: #{self.class.check_file_exists("#{home}/.config/monitor.conf")}"
    puts "  .config/mac-watcher: #{self.class.check_file_exists("#{home}/.config/mac-watcher")}"
    puts "=================================================="
    
    # Try different approaches to clean up files
    
    # Approach 1: Direct removal with FileUtils
    [
      "#{home}/.wakeup",
      "#{home}/.config/monitor.conf",
      "#{home}/.config/mac-watcher",
      "/usr/local/bin/mac-watcher"
    ].each do |path|
      if File.directory?(path)
        FileUtils.rm_rf(path)
        puts "Removed directory: #{path}"
      elsif File.exist?(path)
        FileUtils.rm_f(path)
        puts "Removed file: #{path}"
      else
        puts "Not found: #{path}"
      end
    end
    
    # Approach 2: Try using system commands directly
    system "rm -f #{home}/.wakeup"
    system "rm -f #{home}/.config/monitor.conf"
    system "rm -rf #{home}/.config/mac-watcher"
    
    # Approach 3: Create and run a cleanup script with proper permissions
    cleanup_script = "#{Dir.tmpdir}/mac-watcher-cleanup.sh"
    File.open(cleanup_script, "w") do |f|
      f.puts "#!/bin/bash"
      f.puts "rm -f ~/.wakeup ~/.config/monitor.conf"
      f.puts "rm -rf ~/.config/mac-watcher"
      f.puts "echo 'Cleanup script executed'"
    end
    
    FileUtils.chmod(0755, cleanup_script)
    system "#{cleanup_script}"
    FileUtils.rm_f(cleanup_script)
    
    # Stop sleepwatcher service if it's running and not needed
    system "pgrep -x sleepwatcher >/dev/null && brew services stop sleepwatcher || true"
    
    # Log after cleanup
    puts "\nConfig files after post-uninstall cleanup:"
    puts "  .wakeup: #{self.class.check_file_exists("#{home}/.wakeup")}"
    puts "  .config/monitor.conf: #{self.class.check_file_exists("#{home}/.config/monitor.conf")}"
    puts "  .config/mac-watcher: #{self.class.check_file_exists("#{home}/.config/mac-watcher")}"
    puts "=================================================="
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
        brew uninstall ramanaraj7/tap/mac-watcher
        
      If the automatic cleanup doesn't work, manually clean up with:
        rm -f ~/.wakeup ~/.config/monitor.conf
        rm -rf ~/.config/mac-watcher
        
      For a complete reset of all services and files:
        brew services stop sleepwatcher
        brew uninstall ramanaraj7/tap/mac-watcher
        rm -f ~/.wakeup ~/.config/monitor.conf
        rm -rf ~/.config/mac-watcher
    EOS
  end
  
  test do
    system "#{bin}/mac-watcher", "--help"
  end
end 