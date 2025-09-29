# Translation Locale Editor

A desktop Flutter application for editing JSON translation files. This tool allows you to load multiple locale files, edit translation values, and export them back to individual JSON files.

## Features

- **Load Multiple Locale Files**: Import multiple JSON translation files at once
- **Visual Editor**: Clean, intuitive interface for editing translation keys and values
- **Search & Filter**: Quickly find specific translations using the search functionality
- **Locale Switching**: Switch between different locales with a sidebar selector
- **Real-time Editing**: Changes are tracked and marked as unsaved
- **Export Functionality**: Export individual locale files or all locales at once
- **Error Handling**: Robust error handling for malformed JSON files

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Desktop development environment (Windows, macOS, or Linux)

### Installation

1. Clone or download this project
2. Navigate to the project directory
3. Install dependencies:
   ```bash
   flutter pub get
   ```

### Running the Application

For desktop development, run:
```bash
flutter run -d windows  # For Windows
flutter run -d macos    # For macOS
flutter run -d linux    # For Linux
```

Or build for release:
```bash
flutter build windows
flutter build macos
flutter build linux
```

## Usage

1. **Load Translation Files**: Click "Load Files" to select one or more JSON translation files
2. **Select Locale**: Use the sidebar to switch between different locales
3. **Edit Translations**: Click on any translation value to edit it
4. **Search**: Use the search bar to filter translations by key or value
5. **Export**: Use "Export Current" to save the current locale or "Export All" to save all locales

## File Format

The application expects JSON files with the following structure:
```json
{
  "key1": "translation value 1",
  "key2": "translation value 2",
  "key3": "translation value 3"
}
```

## Dependencies

- `file_picker`: For file selection dialogs
- `path_provider`: For file system access
- `path`: For file path manipulation

## Building for Distribution

To create a distributable version:

```bash
# For Windows
flutter build windows --release

# For macOS
flutter build macos --release

# For Linux
flutter build linux --release
```

The built application will be available in the `build/` directory.
