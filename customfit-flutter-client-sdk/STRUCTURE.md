# CustomFit Flutter SDK Directory Structure

This document outlines the standard directory structure for the CustomFit Flutter SDK, which follows the same patterns as the Kotlin SDK for consistency across platforms.

## Standard Directory Structure

```
customfit-flutter-client-sdk/
  lib/
    src/
      analytics/
        event/         # Event tracking classes
        summary/       # Analytics summaries
      client/
        listener/      # Feature flag and config change listeners
        managers/      # Component managers (config, user, etc.)
      config/
        change/        # Configuration change listeners and events
        core/          # Core configuration classes
      constants/       # SDK constants
      core/
        error/         # Error handling
        model/         # Core data models
        util/          # Core utilities
      extensions/      # Dart extension methods
      lifecycle/       # Lifecycle management
      logging/         # Logging utilities
      network/
        connection/    # Network connectivity monitoring
      platform/        # Platform-specific integrations
      serialization/   # JSON and other serialization utilities
      utils/           # General utilities
```

## Key Components

### Analytics

- `analytics/event`: Handles tracking of user events
- `analytics/summary`: Aggregates data for reporting

### Client

- `client/listener`: Interfaces for event listeners
- `client/managers`: Manages components like config, user settings

### Config

- `config/core`: Core configuration classes
- `config/change`: Change detection and propagation

### Core

- `core/error`: Error handling, results, and categorization
- `core/model`: Data models used throughout the SDK
- `core/util`: Utilities shared across core components

### Networking

- `network/connection`: Network state monitoring and connection management

### Platform

- `platform`: Platform-specific code and feature detection

## Design Principles

1. **Consistency Across Platforms**: The structure mirrors the Kotlin SDK to make it easier for developers to work across platforms.

2. **Separation of Concerns**: Each directory has a clear responsibility.

3. **Dependency Direction**: Higher-level components depend on lower-level ones, not vice versa.

4. **Encapsulation**: Implementation details are hidden behind clear interfaces.

## Import Conventions

For consistency in import statements:

1. Use relative imports: `import '../../logging/logger.dart';`
2. For files in the same directory: `import 'filename.dart';`
3. Avoid package imports for internal files

## Contributing

When contributing to the SDK:

1. Place new files in the appropriate directory based on their function
2. Follow the existing patterns for imports
3. Update this structure document if adding new top-level directories 