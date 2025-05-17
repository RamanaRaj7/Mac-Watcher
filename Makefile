# Makefile for mac-watcher

PREFIX ?= /usr/local
VERSION = 1.0.0

.PHONY: all install uninstall package clean test update-formula

all:
	@echo "Available commands:"
	@echo "  make install        - Install mac-watcher locally (without Homebrew)"
	@echo "  make uninstall      - Uninstall mac-watcher"
	@echo "  make package        - Create a distributable package"
	@echo "  make update-formula - Update formula with correct SHA256 hash"
	@echo "  make clean          - Clean up build artifacts"
	@echo "  make test           - Run tests"

install:
	@echo "Installing mac-watcher..."
	install -d $(PREFIX)/bin
	install -d $(PREFIX)/share/mac-watcher
	install -m 755 bin/mac-watcher $(PREFIX)/bin/mac-watcher
	install -m 755 share/mac-watcher/config.sh $(PREFIX)/share/mac-watcher/config.sh
	install -m 755 share/mac-watcher/monitor.sh $(PREFIX)/share/mac-watcher/monitor.sh
	install -m 755 share/mac-watcher/setup.sh $(PREFIX)/share/mac-watcher/setup.sh
	@echo "Installation complete. Run 'mac-watcher --help' for usage."

uninstall:
	@echo "Uninstalling mac-watcher..."
	rm -f $(PREFIX)/bin/mac-watcher
	rm -rf $(PREFIX)/share/mac-watcher
	@echo "Uninstall complete."

package:
	@echo "Creating package for version $(VERSION)..."
	mkdir -p dist
	tar -czf dist/mac-watcher-$(VERSION).tar.gz bin/ share/ LICENSE README.md Formula/ Makefile
	@echo "Package created at dist/mac-watcher-$(VERSION).tar.gz"

update-formula:
	@echo "Updating formula with correct SHA256 hash..."
	./package.sh
	@echo "Formula updated."

clean:
	rm -rf dist/

test:
	@echo "Running tests..."
	bash -n bin/mac-watcher
	bash -n share/mac-watcher/config.sh
	bash -n share/mac-watcher/monitor.sh
	bash -n share/mac-watcher/setup.sh
	@echo "Tests passed." 