# DNSDeck Makefile

.PHONY: format format-check install-swiftformat help

# Format all Swift files
format:
	@echo "🔧 Formatting Swift files..."
	@swiftformat .
	@echo "✅ Formatting complete!"

# Check if files need formatting (useful for CI)
format-check:
	@echo "🔍 Checking Swift file formatting..."
	@swiftformat --lint .
	@echo "✅ All files are properly formatted!"

# Install SwiftFormat via Homebrew
install-swiftformat:
	@echo "📦 Installing SwiftFormat..."
	@brew install swiftformat
	@echo "✅ SwiftFormat installed!"

# Show available commands
help:
	@echo "Available commands:"
	@echo "  make format           - Format all Swift files"
	@echo "  make format-check     - Check if files need formatting"
	@echo "  make install-swiftformat - Install SwiftFormat via Homebrew"
	@echo "  make help            - Show this help message"
