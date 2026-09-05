# Design system

Tokens live in `lib/core/theme/`. Nothing in a screen should hardcode a colour,
gap, radius, shadow or duration — if a value is missing, add it to a token file
rather than inlining it.

## Colours — `app_colors.dart`

| Role | Light | Dark |
|---|---|---|
| Brand | `primary #16785F` | same, with `primaryLight` for accents |
| Income | `#17864B` | `#56D397` |
| Expense | `#C0392B` | `#FF8A80` |
| Transfer | `#4A6FA5` | `#8FB3E0` |
| Warning | `#E58A00` | `#FFC061` |
| Background | `#F4F6F8` | `#101315` |
| Surface | `#FFFFFF` | `#181C1F` |
| Border | `#E1E6EB` | `#2C3235` |

Semantic money colours are read through the `MoneyColors` extension
(`context.incomeColor`, `context.expenseColor`, …) so they resolve per theme.
`chartPalette` supplies ten series colours; a category without its own colour
falls back to a stable slot derived from its id, so the same category keeps the
same colour everywhere.

**Income and expense never rely on hue alone** — direction is also carried by a
sign (`+`/`−`) and an arrow icon.

## Typography — `app_text_styles.dart`

`displayAmount 36/700` · `headlineLarge 28/700` · `headlineMedium 22/700` ·
`titleLarge 19/600` · `titleMedium 15/600` · `bodyLarge 15.5` · `bodyMedium 14` ·
`bodySmall 12.5` · `caption 11.5/500`

Amount styles use `FontFeature.tabularFigures()` so digits keep their column as
values change. Global text scaling is clamped to 0.85–1.4 in `app.dart`: below
that amounts stop being legible, above it amount columns break.

## Spacing — `app_spacing.dart`

4pt scale: `xxs 2 · xs 4 · sm 8 · md 12 · base 16 · lg 20 · xl 24 · xxl 32 · huge 40`

Semantic: `screenH` (screen gutters), `card` / `cardCompact` (interiors),
`gutter`, `section`, `fabClearance` (bottom padding so a FAB never covers the
last row). Const gap widgets (`AppSpacing.gapMd`, `hGapSm`, …) replace inline
`SizedBox`es.

## Radius — `app_radius.dart`

`xs 8` chips · `sm 10` pills/segments · `md 12` tiles and tracks · `lg 14` inputs
and buttons · `xl 18` cards · `xxl 22` dialogs and sheets · `pill`

## Elevation — `app_elevation.dart`

`level1` cards · `level2` raised controls · `level3` overlays.

Light mode separates surfaces with a hairline border and the faintest lift; dark
mode uses no shadow at level 1 and raises the surface fill instead, because a
shadow on a dark ground is invisible.

## Motion — `app_motion.dart`

`fast 150ms` state flips · `base 220ms` default · `slow 400ms` charts drawing in.
Curves: `enter` (decelerate), `standard`, `exit`.

Nothing animates longer than `slow` — the user is often recording an expense in
a queue.

## Breakpoints — `app_breakpoints.dart`

| Class | Width | Behaviour |
|---|---|---|
| compact | <360 | one column, tightest spacing |
| standard | 360–599 | phone default |
| expanded | 600–904 | large phone landscape, small tablet |
| wide | ≥905 | `NavigationRail` replaces the bottom bar |

Content is capped at **720dp** and centred (`ContentWidth`): beyond that a row's
label and its amount drift apart and stop reading as one line.

`context.layout`, `context.responsive(...)` and `context.gridColumns(...)` are
named to avoid `isPhone` / `isTablet` / `showNavbar`, which `package:get`
already defines on `BuildContext`.

## Components

| Component | Where |
|---|---|
| Card | `AppCard`, `AppCard.compact` |
| Buttons, inputs, chips, sheets, dialogs, snackbars, rail, nav bar | themed centrally in `app_theme.dart` |
| Amount | `AmountText`, `AmountText.signed`, `AmountText.plain` |
| Metric tile | `StatTile` |
| Progress | `AppProgressBar` — turns amber at the alert threshold, red past the limit |
| Category badge / picker | `CategoryAvatar`, `CategoryGrid` |
| Charts | `DonutChart`, `GroupedBarChart` (hand-drawn, no chart dependency) |
| Empty / error / loading | `AppEmptyView`, `AppErrorView`, `AppLoader`, `StateView` |
| Destructive confirm | `ConfirmDialog` |
| Keypad | `AmountKeypad`, `AmountDisplay` |

## Screen patterns

**Dashboard** answers, in order: what do I have → what came in and out → am I
saving → am I within budget → where is it going → what happened recently. Plans
and goals sit below those. Monthly totals and averages live in Reports;
repeating them on the dashboard is what turns it into a wall of numbers.

**Transaction list** groups by day with a net-per-day header, and each row shows
category icon, title, category · account, time and a signed amount.

**Quick add** is a bottom sheet, not a route. It carries its own numeric keypad
rather than the system IME — the keyboard claims roughly half the screen, which
leaves no room to show categories beside the amount. Owning the keypad fits
amount, category grid, account, date and save on one surface, with far larger
targets. The full-page form remains for editing, where the extra fields matter.

## States

Every data screen renders through `StateView` against a sealed `ViewState`:
`Idle`/`Loading` → `AppLoader`, `Empty` → `AppEmptyView` with the action that
resolves it, `Error` → `AppErrorView` with retry, `Loaded` → content. Empty
states always offer the next step rather than only reporting emptiness.
