# Qsidian - Obsidian Helper App Development Tasks

## Project Overview
Qsidian is a lightweight Flutter app designed to complement Obsidian by providing:
- Fast loading times for quick note access
- Powerful home screen widget for note capture and management
- Local markdown file storage compatible with Obsidian vaults
- Basic markdown editing with live preview

## Core Features & Implementation Tasks

### 1. Project Setup & Architecture
- [x] Initialize Flutter project structure
- [x] Set up state management (Provider)
- [x] Configure file system permissions
- [x] Set up local storage structure
- [x] Create app theme and design system

### 2. Vault Management
- [x] Implement folder selection as vault
- [x] Create vault configuration storage
- [x] Add vault switching functionality
- [x] Implement vault validation and error handling
- [x] Create vault settings screen

### 3. Note Management System
- [x] Create Note model class
- [x] Implement markdown file I/O operations
- [x] Add note creation functionality
- [x] Implement note editing with markdown support
- [x] Add note deletion and organization
- [x] Create note search functionality
- [x] Implement note metadata handling (created, modified dates)

### 4. Markdown Editor & Preview
- [x] Integrate markdown editor widget
- [x] Implement live preview functionality
- [x] Add markdown syntax highlighting
- [x] Create toolbar for common markdown actions
- [x] Implement auto-save functionality
- [ ] Add undo/redo support

### 5. Home Screen Widget (Core Feature)
#### Widget Functionality:
- [x] Quick note creation
- [x] Recent notes display
- [x] Note editing from widget
- [x] Vault selection from widget
- [ ] Search notes from widget
- [x] Widget configuration options

#### Technical Implementation:
- [x] Create Android home screen widget foundation
- [x] Implement widget data provider
- [x] Add widget update mechanisms
- [ ] Create widget configuration activity
- [x] Implement widget click handlers
- [ ] Add widget resizing support

### 6. Main App UI
- [x] Create main navigation structure
- [x] Implement notes list screen
- [x] Create note editor screen
- [x] Add settings screen
- [x] Implement vault browser
- [ ] Create about/help screens

### 7. Performance Optimization
- [x] Implement lazy loading for large vaults
- [x] Add file caching mechanisms
- [x] Optimize app startup time
- [x] Implement background processing for widget updates
- [x] Add memory management optimizations

### 8. File System Integration
- [x] Implement file picker for vault selection
- [x] Add file watching for external changes
- [ ] Create backup and restore functionality
- [ ] Implement file conflict resolution
- [ ] Add import/export capabilities

### 9. User Experience Features
- [x] Add dark/light theme support
- [ ] Implement app shortcuts
- [ ] Create onboarding flow
- [ ] Add keyboard shortcuts
- [ ] Implement gesture navigation

### 10. Testing & Quality Assurance
- [x] Write basic unit tests for core functionality
- [ ] Create widget tests for UI components
- [ ] Implement integration tests
- [x] Add error handling and logging
- [ ] Performance testing and optimization

## Technical Stack

### Dependencies
- **flutter**: Framework
- **provider/riverpod**: State management
- **path_provider**: File system access
- **file_picker**: Vault selection
- **shared_preferences**: Settings storage
- **flutter_markdown**: Markdown rendering
- **home_widget**: Home screen widget support
- **path**: File path utilities
- **watcher**: File system monitoring

### Platform-Specific
- **Android**: Home screen widget implementation
- **iOS**: Widget extension (future consideration)

## Development Phases

### Phase 1: Core Foundation (Week 1-2)
- Project setup and architecture
- Basic note management
- Simple markdown editor
- Vault selection

### Phase 2: Widget Development (Week 3-4)
- Home screen widget implementation
- Widget-app communication
- Widget configuration

### Phase 3: Polish & Optimization (Week 5-6)
- UI/UX improvements
- Performance optimization
- Testing and bug fixes
- Documentation

## Future Enhancements (Post-MVP)
- Plugin system architecture
- Cloud sync integration
- Advanced markdown features
- Cross-platform widget support
- Collaboration features

## Success Metrics
- App startup time < 2 seconds
- Widget response time < 500ms
- Support for vaults with 1000+ notes
- Seamless Obsidian vault compatibility
- Positive user feedback on widget functionality

## Notes
- Maintain compatibility with Obsidian's markdown format
- Focus on speed and simplicity
- Widget should be the primary differentiator
- Keep the app lightweight and focused