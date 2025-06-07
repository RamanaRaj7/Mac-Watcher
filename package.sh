#!/bin/bash
# Script to package mac-watcher for Homebrew

set -e

# Parse command line arguments
FORCE_LOCAL=false
FORCE_GITHUB=false
SKIP_GITHUB_CHECK=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --force-local)
      FORCE_LOCAL=true
      shift
      ;;
    --force-github)
      FORCE_GITHUB=true
      shift
      ;;
    --skip-github)
      SKIP_GITHUB_CHECK=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --version)
      if [[ -n "$2" ]]; then
        VERSION="$2"
        shift 2
      else
        echo "Error: Version argument is missing"
        exit 1
      fi
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--force-local] [--force-github] [--skip-github] [--verbose] [--version X.Y.Z]"
      exit 1
      ;;
  esac
done

# Set default version if not specified
VERSION="${VERSION:-1.0.5}"
PKG_NAME="mac-watcher-$VERSION"
DIST_DIR="dist"
ARCHIVE_NAME="$PKG_NAME.tar.gz"

# Use correct GitHub repository name capitalization
REPO_NAME="Mac-Watcher"
GITHUB_URL="https://github.com/RamanaRaj7/${REPO_NAME}/archive/refs/tags/v$VERSION.tar.gz"

echo "Packaging mac-watcher v$VERSION"

# Create distribution directory
mkdir -p "$DIST_DIR"

# Create directory structure for the package
TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/$PKG_NAME"/{bin,share/mac-watcher,Formula}

# Copy files to the package directory
echo "Copying files to temporary directory..."
cp bin/mac-watcher "$TEMP_DIR/$PKG_NAME/bin/"
cp share/mac-watcher/*.sh "$TEMP_DIR/$PKG_NAME/share/mac-watcher/"
cp Formula/mac-watcher.rb "$TEMP_DIR/$PKG_NAME/Formula/"
cp LICENSE README.md Makefile "$TEMP_DIR/$PKG_NAME/"

# Create the archive
echo "Creating archive: $DIST_DIR/$ARCHIVE_NAME"
tar -czf "$DIST_DIR/$ARCHIVE_NAME" -C "$TEMP_DIR" "$PKG_NAME"

# Calculate SHA256 checksum of local package
LOCAL_CHECKSUM=$(shasum -a 256 "$DIST_DIR/$ARCHIVE_NAME" | cut -d ' ' -f 1)
echo "SHA256 of local package: $LOCAL_CHECKSUM"

# Check if GitHub release exists and get its checksum
GITHUB_CHECKSUM=""

if [ "$SKIP_GITHUB_CHECK" = false ] && [ "$FORCE_LOCAL" = false ]; then
    if command -v curl &> /dev/null; then
        echo "Checking GitHub release at $GITHUB_URL..."
        if curl --output /dev/null --silent --head --fail "$GITHUB_URL"; then
            # Download the GitHub release to a temporary file
            echo "GitHub release found. Downloading to calculate SHA256..."
            TEMP_FILE=$(mktemp)
            if curl -s -L "$GITHUB_URL" -o "$TEMP_FILE"; then
                GITHUB_CHECKSUM=$(shasum -a 256 "$TEMP_FILE" | cut -d ' ' -f 1)
                rm "$TEMP_FILE"
                
                echo "SHA256 of GitHub package: $GITHUB_CHECKSUM"
                
                if [ "$LOCAL_CHECKSUM" != "$GITHUB_CHECKSUM" ]; then
                    echo "WARNING: Local package SHA256 differs from GitHub release"
                    if [ "$VERBOSE" = true ]; then
                        echo "  Local:  $LOCAL_CHECKSUM"
                        echo "  GitHub: $GITHUB_CHECKSUM"
                    fi
                    
                    if [ "$FORCE_GITHUB" = true ]; then
                        echo "Using GitHub SHA256 for the formula (--force-github flag is set)"
                    else
                        echo "Using GitHub SHA256 for the formula to ensure compatibility with Homebrew"
                        echo "To use local SHA256 instead, use the --force-local flag"
                    fi
                else
                    echo "SUCCESS: Local package SHA256 matches GitHub release"
                fi
            else
                echo "WARNING: Failed to download GitHub release. Using local package SHA256."
            fi
        else
            echo "GitHub release not found at $GITHUB_URL. Using local package SHA256."
        fi
    else
        echo "WARNING: curl not available. Cannot check GitHub release. Using local package SHA256."
    fi
fi

# Determine which checksum to use based on flags and availability
if [ "$FORCE_LOCAL" = true ]; then
    CHECKSUM_TO_USE="$LOCAL_CHECKSUM"
    CHECKSUM_SOURCE="local package (forced)"
elif [ "$FORCE_GITHUB" = true ] && [ -n "$GITHUB_CHECKSUM" ]; then
    CHECKSUM_TO_USE="$GITHUB_CHECKSUM"
    CHECKSUM_SOURCE="GitHub release (forced)"
elif [ -n "$GITHUB_CHECKSUM" ]; then
    CHECKSUM_TO_USE="$GITHUB_CHECKSUM"
    CHECKSUM_SOURCE="GitHub release"
else
    CHECKSUM_TO_USE="$LOCAL_CHECKSUM"
    CHECKSUM_SOURCE="local package"
fi

# Update the formula with the correct SHA256 and URL
echo "Updating Formula/mac-watcher.rb with the SHA256 checksum from $CHECKSUM_SOURCE"
if ! sed -i.bak "s|url \"https://github.com/[^/]*/[^/]*/archive/refs/tags/v$VERSION.tar.gz\"|url \"$GITHUB_URL\"|" Formula/mac-watcher.rb; then
    echo "ERROR: Failed to update URL in formula"
    exit 1
fi

if ! sed -i.bak "s/sha256 \"[0-9a-f]*\"/sha256 \"$CHECKSUM_TO_USE\"/" Formula/mac-watcher.rb; then
    echo "ERROR: Failed to update SHA256 in formula"
    exit 1
fi

# Update the comment to reflect the source
if ! sed -i.bak "s/# SHA256 of.*$/# SHA256 of the $CHECKSUM_SOURCE file/" Formula/mac-watcher.rb; then
    echo "ERROR: Failed to update SHA256 comment in formula"
    exit 1
fi

# Clean up backup files
rm -f Formula/mac-watcher.rb.bak

# Clean up temporary directory
rm -rf "$TEMP_DIR"

echo "============================================================"
echo "Package created successfully: $DIST_DIR/$ARCHIVE_NAME"
echo "Formula updated with:"
echo "URL: $GITHUB_URL"
echo "SHA256: $CHECKSUM_TO_USE"
echo "SHA256 source: $CHECKSUM_SOURCE"
echo "============================================================"
echo ""
echo "Next steps:"
echo "1. Test the formula locally:"
echo "   brew install --build-from-source ./Formula/mac-watcher.rb"
echo ""
echo "2. Create a new GitHub release with version v$VERSION"
echo "   (if you haven't already)"
echo ""
echo "3. Update your Homebrew tap:"
echo "   cp ./Formula/mac-watcher.rb /path/to/homebrew-tap/Formula/"
echo ""
echo "4. Commit and push changes to both repositories"
echo "============================================================"