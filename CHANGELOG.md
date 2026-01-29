# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-29

### Added
- Initial production-ready release.
- Real-time synchronization with ROCIs-Schedule (lectures, events, and assignments).
- Full Calendar integration with Google Calendar and local tasks.
- Advanced coloring system for calendar events (customizable via bottom sheet).
- Offline-first architecture using Hive for local persistence.
- Secure configuration using environment variables and encryption.
- Multi-language support (English and Hebrew).
- Dark mode, Material 3 theming, and AMOLED support.
- Comprehensive accessibility support (Semantics and screen reader optimizations).
- Global error handling and connectivity awareness.
- CI/CD pipeline via GitHub Actions.

### Changed
- Moved calendar coloring settings from Settings to Calendar page for better UX.
- Optimized task synchronization with Firestore (debouncing and retry logic).

### Fixed
- Fixed critical 300ms debounce issue in task updates to prevent data loss.
- Resolved various Firebase initialization issues across multiple platforms.
- Fixed widget data serialization for Home Widgets.
