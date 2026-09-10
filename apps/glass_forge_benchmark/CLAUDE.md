# Project: GlassForgeBenchmark

## Overview
Device benchmark harness for glass_forge — fixed scenes, frame timing capture, regression gates.

This is a Flutter application built with Clean Architecture and BLoC/Cubit state management, scaffolded with the [Codeable Flutter CLI](https://github.com/gocodeable/codeable-flutter-cli).

## Architecture

### Directory Structure
```
lib/
├── app/view/                    # App entry point (MaterialApp, theme, routing)
├── config/                      # Flavor config, API environment
├── constants/                   # AppColors, AppTextStyle, AssetPaths, Constants
├── core/
│   ├── api_service/             # Dio-based API service with interceptors
│   ├── app_preferences/         # Hive-based local storage (auth tokens, user data)
│   ├── di/modules/              # GetIt dependency injection setup
│   ├── endpoints/               # API endpoint definitions
│   ├── enums/                   # App-wide enums (DataState, ApiCallState)
│   ├── locale/cubit/            # Locale management cubit
│   ├── models/
│   │   ├── api_response/        # API response models
│   │   ├── auth/                # Auth-related models (Hive TypeAdapters)
│   │   └── common/              # Shared models used by 2+ features
│   ├── permissions/             # Permission manager and messages
│   └── field_validators.dart    # Form field validators
├── features/                    # Feature modules (see Feature Structure below)
├── go_router/                   # GoRouter configuration and route definitions
├── l10n/                        # Localization (ARB files, generated code)
├── utils/
│   ├── enums/                   # Domain-specific enums with extensions
│   ├── extensions/              # Dart extensions
│   ├── helpers/                 # Helper utilities (toast, layout, decorations, etc.)
│   ├── response_data_model/     # Response parsing utilities
│   └── widgets/core_widgets/    # Reusable UI components
└── exports.dart                 # Main barrel file
```

### Feature Structure (Clean Architecture)
Each feature follows a strict 3-layer architecture:
```
features/<feature_name>/
├── data/
│   ├── models/          # Data models, DTOs
│   └── repository/      # Repository implementation (calls ApiService)
├── domain/
│   └── repository/      # Abstract repository interface
└── presentation/
    ├── cubit/           # Cubit + State classes
    ├── views/           # Screen widgets
    └── widgets/         # Feature-specific widgets (organized by concern in subfolders)
```

**Layer Rules:**
- **Data layer** handles API calls, parsing, and error catching
- **Domain layer** defines abstract contracts (repository interfaces)
- **Presentation layer** manages UI and state — never calls APIs directly
- Dependencies flow inward: `presentation → domain ← data`

### When to Create a Separate Feature
A concern gets its own feature folder when:
- It has its own cubit/state and repository
- It has its own screens/views
- It would bloat the parent feature's cubit with unrelated state

### Shared Models
Models used by 2+ features belong in `core/models/common/`, not duplicated in each feature's `data/models/`.

---

## Key Patterns

### State Management
- Uses **flutter_bloc** with **Cubit** pattern (not full Bloc with events)
- States use **DataState<T>** enum: `initial`, `loading`, `loaded`, `failure`, `pageLoading`
- Cubits are registered in `lib/app/view/app_page.dart` via MultiBlocProvider
- **No try-catch blocks in cubits** — error handling belongs in the repository
- **No direct API/service calls from cubits** — always go through the repository
- Use `context.read<MyCubit>()` for actions, `BlocBuilder` for state-dependent UI
- Cache cubit references in local variables when using multiple cubits

### State Pattern
States use `Equatable` with a `DataState<T>` wrapper for each async data field:
```dart
class MyFeatureState extends Equatable {
  const MyFeatureState({
    this.items = const DataState<ItemsResponseModel>.initial(),
    this.deleteState = const DataState<void>.initial(),
  });

  final DataState<ItemsResponseModel> items;
  final DataState<void> deleteState;

  MyFeatureState copyWith({
    DataState<ItemsResponseModel>? items,
    DataState<void>? deleteState,
  }) {
    return MyFeatureState(
      items: items ?? this.items,
      deleteState: deleteState ?? this.deleteState,
    );
  }

  @override
  List<Object?> get props => [items, deleteState];
}
```

- Use `DataState<void>` for action-only states (create, delete, update) that don't return data
- Use `DataState<ResponseModel>` for states that hold response data
- **Use `PaginationModel<T>`** for paginated state — never define separate `currentPage`, `totalPages`, `hasMore`, `List<T> items` fields manually

### Dependency Injection
- Uses **GetIt** via `Injector` wrapper class
- Modules registered in `lib/core/di/modules/app_modules.dart`
- Resolve dependencies: `Injector.resolve<Type>()`

### API Layer
- **Dio**-based `ApiService` singleton with centralized error handling
- Auth interceptor adds bearer token from AppPreferences
- Endpoints defined in `lib/core/endpoints/endpoints.dart`
- Response models: `BaseApiResponse<T>`, `ResponseModel<T>`

### Navigation
- Uses **GoRouter** with named routes
- Routes defined in `lib/go_router/routes.dart` (AppRoutes + AppRouteNames)
- Router config in `lib/go_router/router.dart`

### Styling
- Colors: semantic constants grouped by role — surfaces (`background`, `surface`, `surfaceAlt`, `surfaceMuted`), primary (`primary`, `primaryLight`, `primaryMuted`, `primarySoft`), text (`textPrimary`, `textOnPrimary`, `textSecondary`, `textTertiary`), status (`success`, `error`, `warning`, `info`), `border`/`divider`, and overlays (`overlayText`, `overlayTextMuted`, `overlayScrim`)
- Two font families:
  - **BBBPoppins** for headings — `AppFonts.heading` (used by `display`, `h1`–`h5` and their `Medium`/`Bold` variants)
  - **SFProRounded** for body and labels — `AppFonts.body` (used by `p1`/`p2`/`caption`/`overline` and their `Medium`/`Bold` variants)
- Text styles via context extension — size + weight variants:
  - **Display:** `context.display` (43, w400, heading font)
  - **Headings:** `h1`/`h1Medium`/`h1Bold` (32) · `h2`/`h2Medium`/`h2Bold` (28) · `h3`/`h3Medium`/`h3Bold` (24) · `h4`/`h4Medium`/`h4Bold` (20) · `h5`/`h5Medium`/`h5Bold` (18)
  - **Body:** `p1`/`p1Medium`/`p1Bold` (16) · `p2`/`p2Medium`/`p2Bold` (14)
  - **Caption:** `caption`/`captionMedium`/`captionBold` (12) · `overline` (10)
- Text style modifiers: `.primary` (textPrimary), `.secondary` (textOnPrimary), `.light` (textSecondary), `.hint` (textTertiary)
- Assets: `AssetPaths.arrowLeftIcon`, `AssetPaths.searchIcon`, etc.

### Storage
- **Hive** for local persistence via `AppPreferences`
- Auth models use Hive TypeAdapters (TypeId 1, 2, 3)

### Localization
- ARB-based with `flutter_localizations`
- **In widgets/screens (have BuildContext):** `context.l10n.keyName`
- **In non-widget code (validators, formatters, models, utilities):** `Localization.keyName`
- Import for context.l10n: `import 'package:glass_forge_benchmark/l10n/l10n.dart';`
- Import for static access: `import 'package:glass_forge_benchmark/l10n/localization_service.dart';`
- ARB files in `lib/l10n/arb/`
- Static `Localization` service auto-updated via `AppView` builder on every locale change
- Add new getters to `lib/l10n/localization_service.dart` when adding ARB keys

### Form Validation
- `FieldValidators` class with static methods
- Common validators: `emailValidator`, `passwordValidator`, `phoneValidator`, `nameValidator`

### WebSocket (lib/core/socket_service/)
- `SocketService` — centralized WebSocket connection manager with auto-reconnect
- `SocketStatus` enum: `disconnected`, `connecting`, `connected`, `reconnecting`, `error`
- Registered as singleton in DI via `AppModule._setupSocketService()`
- Uses `web_socket_channel` package; URL configured per-flavor in `AppEnv.socketUrl`
- Auth token sent automatically on connect; supports room join/leave events
- Exposes `Stream<Map<String, dynamic>> messages` broadcast stream for consumers
- Connect: `Injector.resolve<SocketService>().connect('roomId')`
- Disconnect on logout: call `.reset()` to tear down and clear room state

### Logging (lib/utils/helpers/logger_helper.dart)
- `AppLogger` — pretty-printed, color-coded console logger with emoji level indicators
- Levels: `info`, `debug`, `warning`, `error`, `verbose`
- Custom `_AppLogPrinter` with ANSI colors, timestamps, tree-style stack traces
- Automatically filtered: `DevelopmentFilter` in debug, `ProductionFilter` in release

### SafeArea (Android 15+ edge-to-edge)
- `AppView` runs an Android SDK check on launch via `device_info_plus`
- On SDK 35+, the builder wraps `MaterialApp.router` content in `SafeArea`
- iOS and older Android keep the standard insets-aware layout
- Do not add manual `SafeArea` to individual screens — `AppView` handles it globally

---

## Core Widgets (lib/utils/widgets/core_widgets/)
Reusable components available through `exports.dart`:
- `CustomAppBar` - App bar with back button, title, actions
- `CustomButton` - Single button widget with named factories:
  - `CustomButton.primary` — `AppColors.primary` filled (default brand action)
  - `CustomButton.secondary` — `AppColors.primaryMuted` filled (alternate brand color)
  - `CustomButton.tertiary` — outlined (`surface` bg, `primary` border)
  - `CustomButton.danger` — `AppColors.error` filled (destructive actions)
  - `CustomButton.text` — text-only ghost (low-emphasis links like "Forgot password?")
- `CustomTextField` - Text form field with validation (factories: `.email`, `.password`, `.number`, `.phone`, `.description`, `.search`)
- `CustomSearchField` - Search input field
- `CustomDropdown` - Dropdown selector
- `SearchableDropdown` - Searchable dropdown with filtering
- `CustomSlidingTab` / `SlidingTab` - Tab bar widgets
- `CustomSectionTitle` - Section header with optional "See All"
- `CustomConfirmationDialog` - Confirmation dialog
- `CustomBottomSheet` - Bottom sheet wrapper
- `PaginatedListView` / `PaginatedGridView` - Paginated scrollable lists
- `RetryWidget` - Error state with retry button
- `EmptyStateWidget` - Empty state display
- `CustomLoadingWidget` / `ShimmerLoadingWidget` - Loading indicators
- `CustomCachedImageWidget` - Network image with shimmer placeholder, asset fallback, custom `errorFallback` widget. Always use this — never raw `Image.network` or `CachedNetworkImage`.
- `UserAvatar` - Circular avatar with deterministic gradient (seeded by user ID), optional photo, and `isLoading` overlay for upload state. Always use for user/profile avatars.

---

## Coding Standards & Quality Rules

### Code Cleanliness
- **Delete unused code** — Remove unused imports, variables, methods, classes, widgets, models, and files. No dead code in the codebase.
- **No commented-out code** — If code is removed, delete it entirely. Git history preserves it if needed. No commented-out files either.
- **No useless comments** — Don't restate what the code does. No doc comments on self-explanatory methods. No `// Section` separators. No `// ===== Section =====` dividers. Only comment where the "why" isn't obvious.
- **Resolve all analyzer hints** — Do not suppress with `// ignore:` unless absolutely necessary. Fix the underlying issue. Run `dart analyze` and ensure zero issues.
- **No TODO comments in committed code** — resolve them before committing or track in issue tracker.

### View Rules
- Views should be **very clean** — no business logic, no data transformations
- **No `_buildXyz()` methods** — extract into separate `StatelessWidget` files in `widgets/`
- **No private widgets in view files** — extract to their own `StatelessWidget` files
- **No business logic in views** — views call cubit methods; cubits handle logic. No increment/decrement methods, no data formatting, no link generation, no conditional computation in views.
- **No `setState()`** — use Cubit state management exclusively
- **View files should not exceed ~1000 lines** — refactor if they do
- Dispose all controllers (`TextEditingController`, `ScrollController`, `FocusNode`, `AnimationController`, `Timer`, etc.) in `dispose()`
- Cache cubit references in local variables when using multiple cubits

### Widget Rules
- Each extracted widget in its **own `.dart` file** as a `StatelessWidget`
- **One class per file** — never put multiple widget classes in a single file. No private `_HelperWidget` classes inside another widget file.
- Widget files go in `feature/presentation/widgets/` organized by concern (subfolders, not flat dumps)
- No business logic in widgets — only UI rendering
- Pass data via constructor parameters, not by reading cubits internally (unless necessary for actions)
- **Exception:** Self-contained bottom sheets that return a result via `Navigator.pop` may use `ValueNotifier` + `ValueListenableBuilder` for ephemeral selection state. This is strictly for UI-only state that doesn't affect feature business state.

### Inline vs Extract — Know the Difference
- **Keep inline** when the code is simple, readable, and used once:
  - A `Padding` with a `Text` — just write it inline
  - A `Row` with 2–3 children — inline is fine
  - A ternary for show/hide: `isVisible ? Widget() : const SizedBox.shrink()`
  - Simple decoration (`Container` with color/border/radius) — inline
- **Extract to a separate widget file** when:
  - The subtree is 30+ lines or 3+ nesting levels deep
  - The same pattern appears in 2+ places — extract immediately
  - The widget has its own logic (onTap handlers, formatting, conditional rendering)
  - It makes the parent screen hard to read
- **Never extract** a 5-line widget into its own file just for the sake of "clean architecture" — that's over-modularization, not cleanliness

### No Over-Engineering
- **No abstract base classes** for a single implementation — just write the class directly
- **No utility functions** used only once — inline the logic
- **No wrapper widgets** that just pass through all props to a child — that's pointless indirection
- **No unnecessary `Container`** — don't wrap a `Text` in a `Container` just for padding, use `Padding` directly. Don't wrap in `Column`/`Row` when there's only one child.
- **No premature generalization** — write the specific thing first. Only generalize when you have 2+ concrete uses.
- **Three similar lines is better than a premature abstraction** — copy-paste is fine until a real pattern emerges

### Spacing & Layout Consistency
- Use `SizedBox(height: N)` / `SizedBox(width: N)` for spacing, not `Padding` with a single side
- Stick to the spacing scale: 4, 8, 12, 16, 20, 24, 32, 40, 48 — no arbitrary values like 13 or 27
- Use `EdgeInsetsDirectional` (not `EdgeInsets`) for RTL support
- Standard screen horizontal padding: 16
- Standard section spacing: 24
- Standard item spacing in lists: 12 or 16

### Cubit Lifecycle
- **Never fetch data in the cubit constructor** — use an `init()` method called from the screen
- Simple setters are one-liners: `void setEmail(String v) => emit(state.copyWith(email: v));`
- **Don't create a method for every tiny state change** — if you have 5 fields that just need setters, a few generic setters are fine
- **Reset state explicitly** — provide a `resetState()` method when the cubit is reused across navigation (e.g., onboarding flows)

### Type Safety
- **Never use `dynamic`** when the type is known — use the actual type
- **Prefer `Object?` over `dynamic`** when you need a top type (forces null checks)
- **No `as` casts without null safety** — use `as Type?` with null fallback, never bare `as Type` on API data

### BlocBuilder / BlocListener
- **Always use `buildWhen`** on `BlocBuilder` to limit rebuilds
- **Always use `listenWhen`** on `BlocListener` to limit side effects
- **If `listenWhen` checks 5+ variables, split the listener** — use separate focused listeners with `MultiBlocListener`
- Extract complex listener logic into named methods

```dart
BlocListener<MyCubit, MyState>(
  listenWhen: (prev, curr) => prev.deleteState != curr.deleteState,
  listener: _handleDeleteState,
  child: ...
)
```

### Cancel Token Pattern
- Cubits own a `CancelToken? _cancelToken` field for cancellable API calls
- Before each API call: cancel the previous token, create a new one:
  ```dart
  _cancelToken?.cancel();
  _cancelToken = CancelToken();
  ```
- Pass `cancelToken: _cancelToken` through repository → ApiService
- After `await`, check `result.isCancelled` — if true, `return` immediately (do not emit state)
- Cancel the token in `close()`:
  ```dart
  @override
  Future<void> close() {
    _cancelToken?.cancel();
    return super.close();
  }
  ```
- Repository interfaces accept `CancelToken? cancelToken` on methods that hit the network
- `execute()` catches `DioException.cancel` and returns `RepositoryResponse(isSuccess: false, isCancelled: true)`

### Repository Error Handling
- Use `execute()` from `repository_response.dart` for all repository methods — no manual try-catch
- Callbacks passed to `execute()` return `T` directly, not `RepositoryResponse<T>`
- Void operations use `execute<void>(() async { ... })` — no return needed inside the callback
- Business-level failures throw `AppApiException` inside the callback
- No try-catch in cubits — error handling belongs in repositories
- No `response.statusCode == 200` checks — ApiService throws on non-2xx
- Always log errors with `AppLogger.error('descriptive message', exception, stackTrace)`

### Models
- **One model per file** — never put multiple model classes in a single file
- **No model duplication across features** — if two features need the same model, consolidate into one file. Keep the fuller version; rename simpler DTOs distinctly (e.g., `CreateSubscriptionTierRequest` vs `SubscriptionTierModel`)
- Resilient parsing — `as Type? ?? defaultValue`, never crash on missing fields
- List parsing must skip malformed items (map + whereType pattern):
```dart
final items = (json['items'] as List<dynamic>?)
    ?.map((e) {
      try { return ItemModel.fromJson(e as Map<String, dynamic>); }
      catch (_) { return null; }
    })
    .whereType<ItemModel>()
    .toList() ?? [];
```
- No manual Hive adapters — use code generation with `build_runner`
- **Use `PaginationModel<T>`** for paginated state — never define separate pagination fields
- Shared models (used by 2+ features) belong in `core/models/common/`

### Parallelization
- Use `Future.wait` for independent async calls — never await sequentially
```dart
await Future.wait([
  _appPreferences.setAuthToken(authToken),
  _appPreferences.setRefreshToken(refreshToken),
  _appPreferences.cacheSession(stage: stage, data: data),
]);
```

### Custom Components — MANDATORY
- **Dialogs:** Use `CustomConfirmationDialog` — never raw `AlertDialog` or `showDialog` with manual buttons
- **Buttons:** Use `CustomButton` — never raw `ElevatedButton`, `TextButton`, or `OutlinedButton`. Pick the right factory:
  - `.primary` for the main action on a screen
  - `.secondary` for an alternate filled action (uses `primaryMuted`)
  - `.tertiary` for outlined / less-emphasized actions
  - `.danger` for destructive actions (delete, leave, cancel)
  - `.text` for inline links and low-emphasis actions ("Forgot password?", "Skip")
- **Text inputs:** Use `CustomTextField` with named factories (`.email`, `.password`, `.phone`, `.number`, `.description`, `.search`) — never raw `TextField` or `TextFormField`
- **Toasts:** Use `ToastHelper.showSuccessToast()` / `showErrorToast()` / `showInfoToast()` — never raw `SnackBar` or `ScaffoldMessenger`
- **Logging:** Use `AppLogger` — never `print()` or `debugPrint()`
- **Date formatting:** Use `DateTimeHelper` — never raw `DateFormat` directly in features. All date/time formatting must go through `DateTimeHelper` static methods:
  - `DateTimeHelper.formatApiDate(date)` → `yyyy-MM-dd`
  - `DateTimeHelper.formatTime12(time)` → `h:mm a`
  - `DateTimeHelper.formatTime24(time)` → `HH:mm`
  - `DateTimeHelper.formatDisplayDate(date)` → `MMM dd, yyyy`
  - `DateTimeHelper.formatShortWeekday(date)` → `EEE d MMM`
  - `DateTimeHelper.formatShortDate(date)` → `MMM d`
  - If a new format is needed, add it to `DateTimeHelper` first, then use it.
- **Colors:** Use `AppColors` constants — never hardcoded `Color(0x...)` or `Colors.xxx`
- **Bottom sheets:** Use `CustomBottomSheet` for consistent drag handle and styling
- **Network images:** Use `CustomCachedImageWidget` — never raw `Image.network` or `CachedNetworkImage` directly. Pass `errorFallback` when you need a custom error widget (e.g. initials inside `UserAvatar`).
- **User/profile avatars:** Use `UserAvatar` — never compose your own `CircleAvatar` or `ClipOval(Image.network(...))`. Pass `seed` (user/member ID) for deterministic gradient assignment when rendering other users.

### Enums & Extensions
- Create enums for **any finite set of values** (statuses, types, roles, actions, filters)
- String comparisons like `== 'active'` or `== 'pending'` in models/widgets are violations — use enums with `fromString` factories
- Create **enum extensions** for display names, colors, icons — don't scatter switch statements
- Enum files go in `utils/enums/` (shared) or `data/models/` (feature-specific)
- **Never define enums inline** in widget files — always in their own file

```dart
enum OrderStatus { pending, confirmed, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get displayName => switch (this) {
    OrderStatus.pending => 'Pending',
    OrderStatus.confirmed => 'Confirmed',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
  };

  Color get color => switch (this) {
    OrderStatus.pending => AppColors.warning,
    OrderStatus.confirmed => AppColors.info,
    OrderStatus.delivered => AppColors.success,
    OrderStatus.cancelled => AppColors.error,
  };

  static OrderStatus fromString(String value) => switch (value) {
    'pending' => OrderStatus.pending,
    'confirmed' => OrderStatus.confirmed,
    'delivered' => OrderStatus.delivered,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.pending,
  };
}
```

### Naming
- **No spelling mistakes** in class names, variable names, file names, or widget names — typos in code are permanent
- All names should be descriptive and self-documenting
- Files: `snake_case` — e.g., `user_profile_screen.dart`
- Classes: `PascalCase` — e.g., `UserProfileScreen`
- Variables/methods: `camelCase` — e.g., `loadUserProfile()`
- Constants: `camelCase` — e.g., `defaultPageSize`
- Enums: `PascalCase` for type, `camelCase` for values — e.g., `OrderStatus.confirmed`

### Reusability
- **Reusability is a top priority** when writing widgets, utilities, and helpers
- Before creating a new widget, check if a similar one already exists in `utils/widgets/core_widgets/`
- Common UI patterns go in `utils/widgets/core_widgets/`, feature-specific in `widgets/`
- If a widget is used by 2+ features, move it to `core_widgets/` and export via `exports.dart`
- If you find yourself copy-pasting UI code across screens, extract it into a shared widget immediately
- Consistent `BorderRadius` — use standardized values project-wide, not arbitrary per-widget values

### Imports
- **Use package imports** — never relative imports (`import 'package:glass_forge_benchmark/...'` not `import '../../../'`)
- Use `exports.dart` barrel file for commonly used packages (Flutter, BLoC, GoRouter, constants, core widgets)

### AI-Generated Code
- **Do not blindly accept AI-generated code** — review every file it modifies
- If AI generates `setState`, raw `AlertDialog`, generic `catch (e)`, manual Hive adapters, direct `DateFormat`, or hardcoded `Color(0x...)`, fix before committing

### Git Commits
- **No `Co-Authored-By: Claude` or any AI co-author lines** in commit messages
- Use conventional commit prefixes: `feat:`, `fix:`, `chore:`, `refactor:`, etc.

---

## Quick Reference Checklist

When writing or reviewing code, verify:

- [ ] Feature folder follows `data/domain/presentation` structure
- [ ] Cubits have no try-catch — error handling in repositories only
- [ ] Repos use `execute()` from `repository_response.dart` — no manual try-catch
- [ ] Views have no `_build` methods, no `setState`, no business logic
- [ ] Every widget is in its **own file** as a `StatelessWidget` — one class per file
- [ ] `BlocBuilder` has `buildWhen`, `BlocListener` has `listenWhen`
- [ ] Models parse resiliently with `as Type? ?? default` — one model per file
- [ ] `PaginationModel<T>` for paginated state — no manual pagination fields
- [ ] `DataState<T>` wraps every async field in state
- [ ] Custom UI components used (`CustomConfirmationDialog`, `CustomButton`, `CustomTextField`, `CustomBottomSheet`, `ToastHelper`)
- [ ] `DateTimeHelper` for ALL date formatting — no direct `DateFormat`
- [ ] `AppColors` for ALL colors — no hardcoded `Color(0x...)`
- [ ] `AppLogger` for logging — no `print`/`debugPrint`
- [ ] Independent async calls use `Future.wait`
- [ ] Enums for finite value sets — no string comparisons. Enum extensions for display values
- [ ] Enums in their own files in `utils/enums/` or `data/models/` — never inline in widgets
- [ ] No dead code, commented code, useless comments, or `// ignore:` suppressions
- [ ] No model duplication across features — shared models in `core/models/common/`
- [ ] Shared widgets (used by 2+ features) in `core_widgets/` — not cross-feature imports
- [ ] Package imports only — no relative imports
- [ ] View files under ~1000 lines
- [ ] Widget folders organized by concern (subfolders, not flat dumps)
- [ ] No spelling mistakes in names
- [ ] Simple inline code stays inline — no extracting 5-line widgets into separate files
- [ ] No over-engineering — no abstract base for one impl, no wrapper widgets, no unnecessary Container
- [ ] `SizedBox` for spacing — not `Padding` with single side
- [ ] Cubit fetches data via `init()` — never in constructor
- [ ] Cancel token pattern used for API calls — cancel in `close()`, check `isCancelled` after await

---

## Build Flavors
- **development** (`main_development.dart`) - DevicePreview enabled
- **production** (`main_production.dart`) - Production config

## Commands
```bash
# Run development
flutter run --target lib/main_development.dart

# Run production
flutter run --target lib/main_production.dart

# Generate localization
flutter gen-l10n

# Run analysis
flutter analyze

# Auto-fix lints
dart fix --apply
```
