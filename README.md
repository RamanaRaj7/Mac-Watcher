# Mac-Watcher 
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/RamanaRaj7/Mac-Watcher)


if you find it intresting a ⭐️ on GitHub would mean a lot!

A macOS monitoring tool that creates email alerts and captures system information when your Mac wakes from sleep.

## Features

- Email notifications when your Mac wakes from sleep
- Capture screenshots and webcam photos
- Track location information
- Collect network details
- Custom scheduling options for alerts
- Secure and private data storage

## Installation

### Using Homebrew-tap (Recommended)

```bash
brew install ramanaraj7/tap/mac-watcher
```

After installation, all dependencies are automatically installed. You'll just need to set up and configure the monitoring:

```bash
# 1. Set up .wakeup file and default configuration
mac-watcher --setup

# 2. Customize configuration (optional)
mac-watcher --config

# 3. Start the sleepwatcher service
brew services start sleepwatcher

# 4. Test functionality (optional)
mac-watcher --test
```

### Manual Installation

If you prefer to install manually:

```bash
git clone https://github.com/ramanaraj7/mac-watcher.git
cd mac-watcher
make install
mac-watcher --dependencies
mac-watcher --setup
```

## Usage

Mac-Watcher comes with several command-line options:

```
mac-watcher --help            # Display help information
mac-watcher --dependencies    # Check and install dependencies
mac-watcher --setup           # Set up .wakeup file and default configuration
mac-watcher --config          # Customize configuration
mac-watcher --test            # Run the monitor script manually for testing
mac-watcher --diagnostics     # Check current setup
mac-watcher --instructions    # Show detailed instructions
mac-watcher --version         # Display version information
```

Short form options are also available:

```
mac-watcher -h                # Display help information
mac-watcher -d                # Check and install dependencies
mac-watcher -s                # Set up .wakeup file and default configuration
mac-watcher -c                # Customize configuration
mac-watcher -t                # Run the monitor script manually for testing
mac-watcher -D                # Check current setup
mac-watcher -i                # Show detailed instructions
mac-watcher -v                # Display version information
```

## Configuration

Mac-Watcher creates a default configuration file at `~/.config/monitor.conf` during setup. When you run `mac-watcher --config`, you'll be guided through customizing:

- Email settings (recipient, API key)
- Location tracking options
- Screenshot and webcam settings
- Custom scheduling and time restrictions
- Auto-deletion settings for captured data

## Testing

You can manually test the monitoring functionality without waiting for a wake event:

```bash
mac-watcher --test
```

This will run the monitor script, which will:
- Capture screenshots
- Take a webcam photo (if enabled)
- Collect location data (if enabled)
- Send email alerts (if configured)
- Save all data to the configured directory

## Data Storage

By default, all captured data is stored in:
(it's stored in a hidden directory by default to view it press command + shift + .)

```
~/Pictures/.access/YEAR/MONTH/DAY/TIME/
```

You can change this location using the configuration utility.

## Troubleshooting

If you encounter any issues, run the diagnostics tool:

```bash
mac-watcher --diagnostics
```

This will check your configuration and provide guidance for fixing any problems.

### Homebrew Installation SHA256 Mismatch

If you encounter a SHA256 mismatch error when installing via Homebrew, this may be due to differences between the local package and the GitHub release. To resolve this:

1. **Using the latest formula**:
   ```bash
   brew update
   brew tap ramanaraj7/tap
   brew install ramanaraj7/tap/mac-watcher
   ```

2. **Building from source**:
   ```bash
   git clone https://github.com/ramanaraj7/mac-watcher.git
   cd mac-watcher
   brew install --build-from-source ./Formula/mac-watcher.rb
   ```

3. **For developers**: If you're modifying the package, run `./package.sh` to rebuild the package and update the formula with the correct SHA256 hash. The script will automatically detect and use the GitHub release hash when available to ensure compatibility with Homebrew.

## Dependencies

Mac-Watcher automatically installs and uses the following dependencies:

- **sleepwatcher**: Detects when your Mac wakes from sleep
- **CoreLocationCLI**: Captures location information
- **jq**: Processes JSON data
- **imagesnap**: Captures webcam photos
- **coreutils**: Provides enhanced file and text utilities

All dependencies are automatically installed during the Homebrew installation or when you run `mac-watcher --dependencies`.

## License

This project is licensed under the MIT License

## Security & Privacy

Mac-Watcher is designed with privacy in mind. All data is stored locally on your machine and is only shared via email if you explicitly configure it to do so. 
