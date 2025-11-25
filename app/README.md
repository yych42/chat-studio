# Chat Studio Flutter App

A Flutter implementation of the Chat Studio web application for managing and editing conversation datasets.

## Features

- **Conversation Management**
  - Create, edit, and delete conversations
  - Two-panel layout: conversation list (left) and editor (right)
  - Status tracking: Completed, Need Review, Incomplete
  - Add notes and comments to conversations

- **Message Editing**
  - Add, edit, and delete messages
  - Switch between user and assistant roles
  - AI-powered suggestion generation for assistant messages
  - Full conversation history context

- **Filtering & Sorting**
  - Filter conversations by status
  - Sort by date or message count
  - Ascending/descending order

- **Import/Export**
  - Import conversations from JSONL files
  - Export all conversations or only completed ones
  - Compatible with the web version's format

- **Local Storage**
  - SQLite database for persistent storage
  - Fast and reliable data access
  - Cross-platform compatibility

## Project Structure

```
lib/
├── models/
│   ├── message.dart
│   ├── conversation_state.dart
│   └── conversation.dart
├── services/
│   ├── database_service.dart
│   ├── api_service.dart
│   └── import_export_service.dart
├── widgets/
│   ├── message_item.dart
│   ├── add_message_form.dart
│   ├── conversation_annotation.dart
│   ├── conversation_editor.dart
│   └── conversation_list.dart
├── screens/
│   └── home_screen.dart
└── main.dart
```

## Requirements

- Flutter SDK 3.7.2 or higher
- Dart 3.7.2 or higher

## Setup

1. Install dependencies:
```bash
cd app
flutter pub get
```

2. Configure API endpoint (optional):
   - The app uses `http://localhost:3000/api/suggest` by default for AI suggestions
   - To change this, modify `lib/services/api_service.dart`

3. Run the app:
```bash
flutter run
```

## Dependencies

- **provider**: State management
- **sqflite**: Local SQLite database
- **http**: API calls for AI suggestions
- **file_picker**: Import JSONL files
- **path_provider**: File system access
- **uuid**: Generate unique IDs
- **intl**: Date formatting

## Data Models

### Message
```dart
{
  role: "user" | "assistant",
  content: String
}
```

### ConversationState
```dart
{
  status: "completed" | "incomplete" | "need_review",
  comment: String
}
```

### Conversation
```dart
{
  id: String,
  messages: List<Message>,
  state: ConversationState,
  createdAt: DateTime,
  updatedAt: DateTime
}
```

## API Integration

The app integrates with the OpenPipe API for AI-powered message suggestions:

- **Endpoint**: POST `/api/suggest`
- **Request**: `{ conversationHistory: Message[] }`
- **Response**: `{ suggestion: string }`

To enable this feature, ensure the backend API is running with the `OPENPIPE_API_KEY` environment variable set.

## Platform Support

The app supports:
- iOS
- Android
- macOS
- Windows
- Linux
- Web

## Building for Production

### Android
```bash
flutter build apk
```

### iOS
```bash
flutter build ios
```

### macOS
```bash
flutter build macos
```

### Windows
```bash
flutter build windows
```

### Linux
```bash
flutter build linux
```

### Web
```bash
flutter build web
```

## License

This project follows the same license as the parent Chat Studio project.
