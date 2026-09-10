---
name: flutter-audit
description: Perform a deep, exhaustive code and architecture audit of a Flutter project built with Clean Architecture + BLoC/Cubit (Codeable Flutter CLI conventions). Use when the user says "audit", "frontend audit", "code audit", "review the codebase", "clean up the project", "find duplication", "deep dive the code", or asks to inspect architecture/quality/duplication across the Flutter app. Brainstorms dimensions first, reports findings by severity, then executes fixes.
---

# Flutter Deep Code & Architecture Audit

You are a senior Flutter architect performing an exhaustive audit of a Flutter project built
with **Clean Architecture + the BLoC/Cubit pattern**, scaffolded by the Codeable Flutter CLI.
Be thorough and skeptical — assume there are problems and go find them. Do not sample a few
files and generalize; walk the **entire** `lib/` tree, feature by feature, and verify each
dimension against real code.

## Workflow (follow in order)

1. **Brainstorm the audit plan.** Invoke the `superpowers:brainstorming` skill to plan the audit
   — brainstorm every dimension to inspect, prioritize them, decide execution order. Only begin
   the actual audit after brainstorming is complete.
2. **Index the conventions.** Read `CLAUDE.md` end to end (it is the authoritative spec), then
   build a mental index of the shared infrastructure below — most findings are "this code
   reinvented something that already exists."
3. **Sweep every dimension** (§1–§18) across the whole `lib/` tree.
4. **Report** findings grouped by severity, highest first, in the output format below.
5. **Brainstorm the execution plan.** Before touching any code, invoke the
   `superpowers:brainstorming` skill again to plan the fixes — sequence the changes, surface the
   risky cross-cutting refactors (shared widget/model consolidation, enum extraction, moving
   files into `core/`), decide what to batch vs. isolate, and settle the approach. Only start
   editing once the execution plan is agreed.
6. **Execute the fixes**, highest-severity first, obeying every `CLAUDE.md` rule.
7. **Verify** with `flutter analyze` before and after; never claim a fix works without the
   analyzer output to back it.

> **This skill ships inside the project.** The shared infrastructure below is what the Codeable
> Flutter CLI scaffolded into this repo. Confirm exact class/helper names against this project's
> `CLAUDE.md`, `lib/exports.dart`, `lib/utils/helpers/`, and
> `lib/utils/widgets/core_widgets/export.dart` before citing them.

## Shared infrastructure to check usage of

- **State container:** `DataState<T>` (`utils/helpers/data_state.dart`) — variants
  `initial / loading / loaded / failure / pageLoading`, getters `isLoaded/isFailure/isLoading/
  isEmpty/hasError`, `errorMessage`, `errorCode`, `map<R>()`.
- **Repository wrapper:** `RepositoryResponse<T>` + the `execute<T>()` helper
  (`utils/helpers/repository_response.dart`) — `isSuccess / data / message / errorCode /
  details / isCancelled`. Business failures raised as `AppApiException`.
- **Pagination:** `PaginationModel` (`core/models/pagination_model.dart`) — `currentPage /
  totalPages / totalItems / hasMore`.
- **HTTP:** `ApiService` singleton (Dio) + `Endpoints` constants + `ApiResponseParser`
  (`utils/response_data_model/api_response_parser.dart` — `parse / parseList / parseValue`).
  `AppApiException` carries `message / statusCode / errorCode / details`.
- **DI:** `Injector.resolve<T>()` / `Injector.isRegistered<T>()` / `AppModule` (`core/di/`).
- **Core widgets:** `utils/widgets/core_widgets/` (barrel `export.dart`) — `CustomButton`
  (`.primary/.secondary/.tertiary`), `CustomConfirmationDialog`, `CustomTextField`,
  `CustomDropdown`, `SearchableDropdown`, `PaginatedListView`, `CustomRetryWidget`,
  `EmptyStateWidget`, `ShimmerLoadingWidget`/`SkeletonLoadingWidget`, `CustomRefreshIndicator`,
  `customAppBar`/`CustomAppBar`, `UserAvatar`, `OtpInputField`, `PhoneField`, `SelectableChip`,
  `StepProgressBar`, etc.
- **Helpers:** `ToastHelper` (`showSuccessToast/showErrorToast/showInfoToast`), `AppLogger`
  (`debug/info/warning/error/verbose` + `apiRequest/apiResponse/apiError`), `DateTimeHelper`
  (ALL date/time formatting — 40+ methods), `DecorationsHelper` (`whiteCard/circular/cardShadow`),
  `LayoutHelper`, `ResponsiveHelper` (+ `context.isMobile/isTablet/screenWidth`),
  `StringHelpers` (`toTitleCase/toLetterCase/sPluralise`), `PriceFormatter`, `HapticHelper`,
  `FocusHandler`.
- **Styling:** `AppColors`, `AppFonts`, text styles via `BuildContext` extension
  (`context.display/h1/h1Bold/h2/p1/p1Medium/p2/caption`, aliases `t1/b1/l1`, plus `.copyWith`),
  `AssetPaths`, `AppConstants` (`paginationLimit`, field max lengths, etc.).
- **Localization:** `context.l10n.key` in widgets; static `Localization.key` in non-widget code
  (validators, formatters, models, services). New ARB keys require a getter in
  `l10n/localization_service.dart`.
- **Navigation:** GoRouter — `AppRoutes` (paths) + `AppRouteNames` (names) in `go_router/`,
  navigate via `context.pushNamed(AppRouteNames.x)` / `context.goNamed(...)` / `context.pop()`.
- **Storage:** `AppPreferences` (Hive) for local persistence; Hive models via **code-generated**
  TypeAdapters only.

---

## 1. Architecture & Layering

- Is the `data → domain ← presentation` dependency direction respected, with **no cross-layer
  leakage**? Presentation must never import from a feature's `data/`. Cubits depend on the
  **domain** repository interface (`XRepository`), never the impl (`XRepositoryImpl`).
- Do **cubits call `ApiService` / `Dio` / `Endpoints` / `ApiResponseParser` directly**? They
  must go through a repository. Flag every direct API/service/parse call from a cubit.
- Is there **business logic in views or widgets** — increment/decrement, arithmetic, data
  transformation, formatting, link/URL building, conditional computation, filtering, sorting,
  grouping, validation? All of it belongs in the cubit (or a helper). Views call cubit methods;
  widgets render passed-in data.
- Are there **`_buildXyz()` methods or private `_Widget` classes inside view files**? Every
  widget must be its own public `StatelessWidget` in its own file under
  `presentation/widgets/`, one class per file, organized by concern in subfolders (not a flat
  dump).
- Any **`setState()`** anywhere? Banned — state flows through Cubit. (Allowed exception:
  self-contained bottom sheets returning a result via `Navigator.pop`, using
  `ValueNotifier`/`ValueListenableBuilder` for ephemeral UI-only selection.)
- Does each concern that has its own cubit+state, repository, and screens live in its own
  `features/<role>/<feature>/` folder, instead of bloating an unrelated parent cubit?
- Is the folder/module structure consistent across features and **scalable** for new roles
  (admin/kid/parent/…)? Flag features that deviate from the
  `data/{models,repository} · domain/repository · presentation/{cubit,views,widgets}` shape.
- Are **view files over ~1000 lines**? Flag for extraction.
- **Lifecycle & leaks:** are `TextEditingController`, `ScrollController`, `FocusNode`,
  `AnimationController`, `Timer`, `StreamSubscription`, `PageController`, `TabController`
  disposed in `dispose()` / cubit `close()`? Flag every undisposed resource and every
  subscription not cancelled.

## 2. State Management (Cubit / DataState)

- Does **every async field in a state class use `DataState<T>`** (and `DataState<void>` for
  action-only create/update/delete)? Flag raw `bool isLoading` / `String? error` /
  `List<T> items` / `bool hasLoaded` fields that should be `DataState`.
- Are state classes `Equatable` with a **complete `props`** (every field present) and a correct
  `copyWith` (every field present, with the right nullable-override pattern for fields that
  must be settable to `null`)? Missing-from-`props` → stale UI; missing-from-`copyWith` → can't
  update.
- Is **paginated state using `PaginationModel`**, never hand-rolled `currentPage`/`totalPages`/
  `hasMore`/list fields? Is page-append logic correct (no duplicate items, no lost items)?
- **No `try-catch` in cubits.** Error handling belongs in the repository. Flag every one.
- Does every `BlocBuilder` have a **`buildWhen`** and every `BlocListener` a **`listenWhen`**?
  Flag missing ones.
- Are listeners checking **5+ state variables** split into focused listeners under a
  `MultiBlocListener`? Is complex listener logic extracted into named methods (not inline lambdas)?
- Are cubit references **cached in a local variable** when multiple cubits are read in one build?
- Are `emit`s after `await` guarded against a closed cubit where needed? Any `emit` called
  after `close()` risk?
- Is there **UI/presentation state living in the cubit that should be local ephemeral** (and
  vice-versa)? Cubits hold feature/business state, not transient widget animation flags.

## 3. Repository & Error Handling

- Does **every repository method use `execute<T>()`** with no manual `try-catch`? Flag manual
  try-catch, and flag callbacks that return `RepositoryResponse` instead of `T` directly.
- Any **`response.statusCode == 200` / `!= 200` checks**? `ApiService` throws on non-2xx —
  remove them.
- Are business-level failures thrown as **`AppApiException`** (not generic `Exception` or a
  raw string) inside the `execute` callback? Is `errorCode` surfaced where the UI branches on
  a specific server code?
- Is response parsing done via **`ApiResponseParser.parse / parseList / parseValue`** rather
  than ad-hoc `response.data['data']...` digging?
- Are errors logged with **`AppLogger.error('descriptive message', e, stackTrace)`** at the
  catch point — never swallowed silently, never `catch (_) {}` without a reason?
- Are failures surfaced consistently (via `ToastHelper` or a `CustomRetryWidget`/failure UI),
  with uniform messaging and correct success/failure branching?
- Are independent network calls inside a repository/cubit run with **`Future.wait`**, not
  awaited sequentially?

## 4. Models — No Duplication, Resilient Parsing

- **One model per file** — flag any file declaring 2+ model classes.
- **Resilient parsing** everywhere: `json['x'] as Type? ?? default`, never a bare cast that
  crashes on a missing/null/wrong-typed field. Numbers via `(json['x'] as num?)?.toInt()`.
- List parsing must **skip malformed items** (map → try/catch → `whereType`), never drop the
  whole list on one bad element.
- **No duplicated or near-duplicated models across features.** This is a priority: a model used
  by 2+ features must live in `core/models/common/`. Actively hunt for duplicates —
  same/similar field sets under different names, copy-pasted `fromJson` bodies, two features
  each defining their own `UserModel`/`ProductModel`/`AddressModel`. Consolidate to one,
  keep the fuller version, and name request DTOs distinctly (e.g. `CreateXRequest` vs `XModel`).
- **No manual Hive `TypeAdapter`s** — must be code-generated via `build_runner`.
- Are models `Equatable` with correct `props`? Do they have `copyWith`/`toJson` where needed,
  and is `toJson` symmetric with `fromJson`?
- Are enums used inside models (not raw status strings) — see §7.

## 5. Duplication & DRY (logic, widgets, constants) — hunt aggressively

Treat duplication as a first-class defect. For each item, name **all** call sites and propose
the single shared home.

- **Duplicated logic:** the same parsing, mapping, validation, calculation, grouping, sorting,
  or formatting implemented in 2+ cubits/repos/widgets → extract to a shared helper, extension,
  or repository method. (Method: grep for repeated literal patterns, repeated `switch`
  statements, and copy-pasted blocks across features.)
- **Duplicated widgets / UI blocks:** the same card, row, header, badge, tile, empty/error/
  loading state copy-pasted across screens → extract one `StatelessWidget`. If used by **2+
  features**, it belongs in `core_widgets/` + the `export.dart` barrel — **never** import a
  widget across feature boundaries.
- **Reinvented shared infra:** any local re-implementation of something that already exists —
  a bespoke loading spinner instead of `ShimmerLoadingWidget`, a hand-rolled error+retry
  instead of `CustomRetryWidget`, a custom empty state instead of `EmptyStateWidget`, manual
  pull-to-refresh instead of `CustomRefreshIndicator`, manual infinite scroll instead of
  `PaginatedListView`, a private date formatter instead of `DateTimeHelper`, an inline price
  string instead of `PriceFormatter`, a local `BoxDecoration` instead of `DecorationsHelper`.
- **Duplicated constants / magic values:** the same number, key, duration, padding, or string
  literal repeated → a single named constant (`AppConstants` or a feature constant).
- **Duplicated styling:** repeated `BoxDecoration`/`BorderRadius`/shadow/gradient definitions →
  route through `DecorationsHelper` and standardized radius constants.
- **Duplicated endpoints/strings:** the same endpoint path or user string written twice.
- For every duplication, state the **DRY fix**: where the single source of truth should live
  and which call sites to repoint.

## 6. Reusability & Modularity — mandatory custom components

Flag **every** raw usage where a project component exists:

- Raw `ElevatedButton` / `TextButton` / `OutlinedButton` / `InkWell`-as-button →
  `CustomButton` / `CustomOutlineButton`.
- Raw `AlertDialog` / `showDialog` with manual buttons → `CustomConfirmationDialog`.
- Raw `SnackBar` / `ScaffoldMessenger` → `ToastHelper`.
- `print()` / `debugPrint()` / `log()` → `AppLogger`.
- Direct `DateFormat(...)` / `intl` formatting in features → a `DateTimeHelper` method (if a
  new format is needed, **add it to `DateTimeHelper` first**, then use it).
- Raw `AppBar(...)` → `customAppBar(...)` / `CustomAppBar`.
- Raw `TextField` / `TextFormField` → `CustomTextField`; raw dropdowns → `CustomDropdown` /
  `SearchableDropdown`; raw OTP/phone inputs → `OtpInputField` / `PhoneField`.
- Manual avatar/initials → `UserAvatar`; manual chips → `SelectableChip`.
- Could domain logic be made more modular so new roles/features can be added with minimal
  effort? Flag tight coupling, role-specific code that should be generic, and shared flows that
  were forked per role instead of parameterized.
- Are shared helpers/widgets actually used **consistently** everywhere, or do some modules
  reinvent them (cross-reference with §5)?

## 7. Enums & Magic Values

- Any **string comparison on a finite set** (`== 'active'`, `== 'pending'`, `contains('admin')`,
  status/type/role/filter checks) → must be an enum with a `fromString` factory (resilient
  default, no throw).
- Are enums defined **inline in widget files**? They must live in their own file under
  `utils/enums/` (shared) or the feature's `data/models/` (feature-specific).
- Are display names / colors / icons / labels for an enum scattered across `switch` statements
  in widgets instead of centralized in an **enum extension**? Use modern `switch` expressions
  and rely on **exhaustiveness** (no `default:` that hides missing cases).
- **Magic numbers/strings** (page sizes, durations, limits, padding, animation values, map
  keys, query-param names) → named constants.

## 8. Styling & Theming Consistency

- **No hardcoded `Color(0x...)` or `Colors.xxx`** — every color from `AppColors`. Flag each
  literal and map it to the nearest token.
- **No inline `TextStyle(...)`** for standard text — use `context.h1/p1/t1/b1/...` + `.copyWith()`
  for tweaks. Flag raw `TextStyle`, `GoogleFonts`, and hardcoded `fontFamily`/`fontSize`.
- **No hardcoded asset path strings** — use `AssetPaths`. Flag inline `'assets/...'` literals.
- **Inconsistent / arbitrary `BorderRadius`, spacing, `EdgeInsets`, icon sizes** — flag and
  standardize toward project values.
- Hardcoded sizes that should be responsive — consider `ResponsiveHelper` / `LayoutHelper`
  where the screen adapts.
- Is dark/light handling (if any) consistent, or are colors picked manually per widget?

## 9. Localization & Content

- Hardcoded user-facing strings in widgets → `context.l10n.key`; in non-widget code →
  `Localization.key`. Flag **every** literal string rendered to the user (including button
  labels, dialog text, toasts, hints, error messages, empty-state copy).
- Are new ARB keys backed by a getter in `l10n/localization_service.dart`?
- Any unused ARB keys / missing translations / placeholder-arg mismatches?
- Plurals and parameterized strings handled via ARB (or `StringHelpers.sPluralise`), not string
  concatenation.

## 10. Performance & Scalability

- Rebuild scope: missing `buildWhen`/`listenWhen` (§2), plus `BlocBuilder`s placed too high in
  the tree → push them down to the smallest subtree that depends on the state.
- Independent async work run with **`Future.wait`**, not sequential awaits (§3).
- Long lists lazy (`ListView.builder` / `PaginatedListView`), never a giant `Column` of
  everything inside a `SingleChildScrollView`. `shrinkWrap`/nested-scroll misuse flagged.
- **`const` constructors** used wherever possible to cut rebuilds — flag obvious missing `const`.
- Expensive work (parsing, sorting, filtering, formatting, regex) done **inside `build()`** that
  should be computed once in the cubit/state.
- Images: network images cached (`CachedNetworkImage`), SVGs via `flutter_svg`, sensible
  `cacheWidth`/resizing for large images. No giant un-resized images in lists.
- `RepaintBoundary` around expensive, independently-animating subtrees where warranted.
- Heavy synchronous JSON parsing on large payloads — consider isolates/`compute` if it blocks
  the UI thread.
- Animations disposed and not running off-screen; no unbounded timers/streams.

## 11. Navigation (GoRouter)

- Routes defined in **both** `AppRoutes` (path) and `AppRouteNames` (name), and navigation uses
  named routes (`context.pushNamed(AppRouteNames.x)`), not hardcoded path strings.
- New screens wired into the router and imported via `go_router/exports.dart`.
- Auth-gating in the `redirect` is consistent — every route that should require auth is gated;
  deep links resolve sanely for unauthenticated users.
- Args passed via typed `extra` / path params, not via globals or static mutable state.
- `context.pop()` used (not `Navigator.pop`) for GoRouter consistency; no orphaned routes.

## 12. Forms & Input

- Validation via `FieldValidators` (`emailValidator`, `passwordValidator`, `phoneValidator`,
  `nameValidator`, …), not ad-hoc regex scattered in widgets.
- `TextEditingController`/`FocusNode` disposed; form keys handled correctly.
- Input formatters / `maxLength` (e.g. `AppConstants.phoneFieldMaxLength`) applied where
  relevant; keyboard types set appropriately.
- Submit buttons reflect loading state (`DataState`) and are disabled while submitting to
  prevent double-submit.

## 13. Security & Privacy

- Are **tokens / passwords / PII / full request bodies / OTPs** logged via `AppLogger` or
  interceptors? Nothing sensitive may reach the console in release. Flag each.
- Is auth state checked consistently before protected navigation? Any route that should be
  auth-gated but isn't?
- Any secrets/API keys/base URLs hardcoded in Dart instead of flavor env config
  (`config/env/`)?
- Local storage: is sensitive data in `AppPreferences`/Hive stored appropriately (and cleared
  on logout)?

## 14. Code Quality & Cleanliness

- **Dead code:** unused imports, variables, fields, methods, classes, widgets, models, assets,
  and whole files. Remove.
- **Commented-out code / files** — delete entirely (git preserves history).
- **Useless comments** restating the code, `// Section` / `// ===== =====` dividers, doc
  comments on self-explanatory members — remove. Keep only non-obvious "why" comments.
- **`// ignore:` suppressions** — fix the underlying issue unless truly unavoidable; if kept,
  it must be justified.
- **Overly complex / long functions & widgets** — break down. Deeply nested widget trees →
  extract.
- **Naming:** descriptive, consistent — `snake_case` files / `PascalCase` classes /
  `camelCase` members / `PascalCase.camelCase` enums — and **zero spelling mistakes** in any
  identifier, label, or file name.
- **No `TODO`/`FIXME`** left in committed code.
- **Package imports only** (`package:<app>/...`) — flag every relative import (`../../`).
- Barrel `exports.dart` used for common imports rather than long repetitive import lists.

## 15. Dart / Flutter Language Best Practices

- `flutter analyze` must be **zero issues** — run it; every issue is a finding.
- **`BuildContext` across `async` gaps:** any `context` used after an `await` inside a `State`
  must be `mounted`-guarded. Flag each. (If the analyzer ignores
  `use_build_context_synchronously`, you must catch these manually.)
- **Null safety:** avoid `!` bang operators on values that can realistically be null; prefer
  `?.`, `??`, and pattern checks. Flag risky `!`, `late` that may be read before init, and
  force-unwrapped map lookups.
- **Immutability:** widget fields `final`; prefer `const`; model classes immutable with
  `copyWith`. Flag mutable widget fields.
- Prefer **`switch` expressions** with exhaustiveness over if-else chains on enums; use
  **sealed/`Equatable`** patterns where modeling variants.
- Collection idioms: spread/`collection-if`/`collection-for` over manual `.add` loops where
  cleaner; `whereType`, `map`, `firstWhereOrNull` over manual loops.
- Keys on list items where identity/reordering matters; avoid index-as-key when items mutate.
- No business logic in `initState` beyond a single post-frame trigger to a cubit; no awaits in
  `initState` without guards.
- Avoid `Future`-returning calls that aren't awaited or `unawaited(...)`-marked intentionally.
- Avoid rebuilding `MediaQuery.of(context)` repeatedly — read once; prefer `context.screenWidth`
  helper.

## 16. Accessibility & UX polish (where applicable)

- Tap targets reasonably sized; `Semantics`/labels on icon-only buttons where it matters.
- Text scales without overflow (no fixed heights that clip scaled text); `Flexible`/`Expanded`
  used to prevent `RenderFlex` overflow.
- Loading, empty, and error states exist for every async screen (not a blank screen on
  failure) — backed by `DataState` branches and the shared state widgets.
- Images/SVGs have sensible fallbacks; no broken-asset crashes.

## 17. Assets, Config & Build

- Every asset referenced exists and is declared in `pubspec.yaml`; no unused assets in
  `assets/`. Asset paths only via `AssetPaths`.
- Flavors (`development` / `production`) and env config are clean; no dev-only config leaking
  into production.
- `pubspec.yaml`: no unused dependencies; versions consistent; no duplicate packages doing the
  same job.
- Generated files (`l10n`, Hive adapters) up to date and not hand-edited.

## 18. Testing (if a `test/` dir exists)

- Are cubits/repositories/models covered? Flag critical untested business logic.
- Are tests meaningful (assert behavior) rather than trivial/snapshot-only?
- If no tests exist, note it as a gap and suggest the highest-value units to cover first.

---

## Verification (do this, don't assume)

- **Run `flutter analyze`** and fold the results into the findings. Run `dart fix --apply`
  where safe.
- After fixes, **re-run `flutter analyze`** and confirm zero issues. Do not claim a fix works
  without the analyzer output to back it. If you can build/run, do so to confirm no regressions.

## Output Format

For **each finding**, provide:

1. **Location** — `file_path:line` (clickable).
2. **Issue** — what's wrong and which convention/rule it violates (cite §/`CLAUDE.md` where apt).
3. **Severity** — Critical / High / Medium / Low.
4. **Fix** — concrete recommendation or code snippet using the real project APIs above.

Group findings by **severity, highest first**. For **duplication findings, list every call
site** and the single shared destination. Then give a **prioritized action list of the top 5
things to fix immediately**.

**Then execute all the fixes**, working highest-severity first. While fixing, obey every rule in
`CLAUDE.md`: use the existing custom components, helpers, `DataState`, `execute()`, enums,
`PaginationModel`, and styling tokens; consolidate duplicated models into `core/models/common/`
and duplicated widgets into `core_widgets/`; extract widgets into their own files; keep views
clean (no `_build`, no `setState`, no business logic); package imports only; no dead or
commented code. After applying fixes, re-run `flutter analyze` and report the final state, plus
a short summary of what was consolidated/deduplicated.

## Scope control

- If the user names a feature/folder/branch, scope the audit there but still apply every
  dimension. Otherwise audit all of `lib/`.
- For very large codebases, consider dispatching parallel `Explore` agents per `features/<role>/`
  subtree to gather findings, then synthesize and fix.
- On a dirty working tree, summarize findings and confirm before mass edits unless the user
  said to execute fixes directly.
