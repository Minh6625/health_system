---
trigger: glob
globs: **/*.dart
---

# Flutter Rules — health_system/lib

Áp dụng cho mobile UI (Flutter SDK 3.11). Combine với `30-testing-discipline.md` cho widget tests.

## Architecture

**Clean Architecture per feature:**

```
lib/features/<feature>/
├── data/
│   ├── models/         # JSON (de)serialization
│   └── repositories/   # data source impl (HTTP, local DB)
├── domain/
│   ├── entities/       # pure dart domain models
│   ├── repositories/   # abstract interfaces
│   └── usecases/       # business logic (rare; usually skip — call repo directly)
└── presentation/
    ├── providers/      # Riverpod (state)
    ├── screens/        # page widgets
    └── widgets/        # local reusable widgets
```

Shared widgets ở `lib/shared/widgets/`.

## State management

- **Riverpod 2.x** — codebase standard.
- **Provider types:**
  - `Provider` cho immutable computed values
  - `StateProvider` cho simple primitive state
  - `StateNotifierProvider` cho complex state với business logic
  - `FutureProvider` / `StreamProvider` cho async data
- **Async safety:** check `mounted` trước khi `setState`/`Navigator.push` sau await.

## Widget rules

- **Stateless > Stateful.** Default stateless trừ khi cần lifecycle/state cục bộ.
- **Const constructors** mọi nơi có thể (`const Text(...)`, `const SizedBox(...)`) — performance.
- **Extract widget khi `build()` > 100 dòng.**
- **Không nested ternary trong build.** Refactor thành method hoặc widget riêng.
- **Key đúng nghĩa:** `ValueKey` cho list item có id; `UniqueKey` cho widget cần force rebuild.

## Navigation

- **GoRouter** — codebase đã dùng. Router config trong `lib/core/routes/app_router.dart`.
- **Không push routes trực tiếp** — đi qua route name + params.
- **Deep link / FCM open** đi qua `notification_open_router.dart`.

## Accessibility (medical app — mandatory)

- Min font size: **16sp** (body), 14sp (caption exception).
- Min touch target: **48dp × 48dp** (56dp cho emergency/elderly UI).
- Min contrast: **4.5:1** (WCAG AA).
- TalkBack/VoiceOver semantic labels cho mọi interactive widget.
- **Elderly UX:** quan trọng — bottom 40% screen cho main actions (thumb zone).

## Network & async

- **HTTP client:** `dio` hoặc `http` package. Centralize trong `lib/core/network/`.
- **Repository pattern:** screen không gọi http trực tiếp. Đi qua repository.
- **Error handling:** dùng `Either<Failure, T>` (dartz) hoặc Result type. Không throw exception qua boundary.
- **Offline-first:** cache trong local DB (Hive/Isar). Sync khi online.

## FCM (push notifications)

- **Foreground:** `notification_runtime_service.dart` handle.
- **Background/terminated:** `FirebaseMessagingService` + `onBackgroundMessage`.
- **Fall alert** dùng full-screen intent (Android) + critical alert (iOS).
- **Don't navigate** từ background handler — chỉ store deep link, navigate khi app resume.

## Testing

- **Widget test:** `flutter test test/features/<feature>/`. Mock provider qua `ProviderScope` override.
- **Integration test:** `integration_test/` — chạy trên real device cho FCM/native.

## Anti-patterns flag tự động

- `setState()` trong loop hoặc async không check `mounted`
- `BuildContext` lấy qua async gap không check `mounted`
- `dispose()` quên gọi cho controller (TextEditingController, AnimationController)
- `print()` trong production code → dùng logger
- `dynamic` type ở public API
- Hardcode string literal cho text — dùng `app_strings.dart`
- Hardcode color — dùng theme

## Build commands

- `flutter pub get` sau khi pull/sửa `pubspec.yaml`
- `flutter analyze` trước commit (no warnings allowed)
- `flutter test test/<feature>/` trước push
- `flutter build apk --release` / `flutter build ios --release` cho production
