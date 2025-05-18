#!/bin/bash

# Script to update import paths after directory structure changes

# Create backup directory
mkdir -p .backup

# Backup all Dart files
find lib -name "*.dart" -type f -exec cp {} .backup/ \;

echo "Updating imports for logger.dart..."
find lib -name "*.dart" -type f -exec sed -i '' 's|import.*core/logging/logger.dart|import '\''../../logging/logger.dart'\''|g' {} \;

echo "Updating imports for log_level_updater.dart..."
find lib -name "*.dart" -type f -exec sed -i '' 's|import.*core/logging/log_level_updater.dart|import '\''../../logging/log_level_updater.dart'\''|g' {} \;

echo "Updating imports for event files..."
find lib -name "*.dart" -type f -exec sed -i '' 's|import.*events/event_data.dart|import '\''../../analytics/event/event_data.dart'\''|g' {} \;
find lib -name "*.dart" -type f -exec sed -i '' 's|import.*events/event_type.dart|import '\''../../analytics/event/event_type.dart'\''|g' {} \;

echo "Fixing relative paths in files that were moved..."
sed -i '' 's|import.*config/core/cf_config.dart|import '\''../../config/core/cf_config.dart'\''|g' lib/src/logging/log_level_updater.dart

echo "Import paths updated successfully"
echo "Please manually review any files with custom import patterns"
echo "Backups of original files are stored in .backup/"

# Set executable permissions
chmod +x update_imports.sh 