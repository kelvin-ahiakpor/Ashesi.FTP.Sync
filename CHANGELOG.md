# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
- Add support for syncing multiple directories.
- Explore VS Code extension integration.

## [v1.0] - 2024-11-12
### Added
- Initial stable release of Ashesi FTP Sync.
- Automated file synchronization between local directories and Ashesi FTP server.
- Real-time monitoring for file changes using `fswatch` (macOS/Linux) and `FileSystemWatcher` (Windows).
- Secure storage of credentials:
  - Keychain integration for macOS.
  - Encrypted password storage for Windows.
- Configuration file for reusable settings.
- Support for manual and automated syncing.
- Demo videos for macOS and Windows users.
