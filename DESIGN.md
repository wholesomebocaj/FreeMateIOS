# FreeMate design system

Every screen uses one palette, one type scale, and one set of components. The tokens live in `FreeMateIOS/DesignSystem/Theme.swift`. Use them instead of literal colors, fonts, or sizes.

The look takes its cue from the board: warm cream and sage squares on a quiet grouped background, with one calm blue for anything the learner can act on.

## Color

| Token | Use | Light | Dark |
| --- | --- | --- | --- |
| `Theme.accent` | Buttons, links, selection, progress, the board's guide glow | `#2F7CD3` | `#4895EF` |
| `Theme.success` | Correct moves, finished lessons, mastery | `#2E8B57` | `#4CC38A` |
| `Theme.warning` | Hints and gentle nudges after a mistake | `#B86E00` | `#F5A623` |
| `Theme.danger` | Real problems: checkmate, failed sign-in, log out | `#C9372C` | `#FF6961` |
| `Theme.highlight` | The last move on the board, celebrations | `#E8C35A` | `#F5D67A` |
| `Theme.background` | Screen background | system grouped | system grouped |
| `Theme.surface` | Cards and grouped rows | secondary grouped | secondary grouped |
| `Theme.surfaceRaised` | Tiles and stats on a card | tertiary grouped | tertiary grouped |
| `Theme.fill` | Progress tracks, chips, text fields | tertiary fill | tertiary fill |
| `Theme.boardLight` / `Theme.boardDark` | Board squares, same in both modes | `#EEE9DD` / `#8FA68C` | same |

For text, use the semantic styles `.primary`, `.secondary`, and `.tertiary`. Do not use custom grays.

`Theme.topic(_:)` gives each curriculum topic a symbol and color: Fundamentals (accent), Openings (indigo), Tactics (warning), Endgame (success), and Strategy (purple).

Rules:

- **One accent.** Blue means "you can tap this" or "do this next". Do not introduce other brand colors.
- **Mistakes are hints, not errors.** A wrong move or answer uses `warning` with a lightbulb, plus a shake and an error haptic. Keep `danger` for things that really went wrong.
- **Green means done.** Use `success` for completion, never for ordinary buttons.

## Type

All text uses San Francisco through Dynamic Type styles, so it scales with the user's settings.

| Role | Style |
| --- | --- |
| Screen title | Navigation title. Use large on tab roots (Home, Lessons, Openings, Practice, Review) and inline on detail screens. |
| Hero | `.title.weight(.bold)` |
| Section header | A native `Section` header in a `List` |
| Card title | `.title3.weight(.bold)`, or `.headline` in dense rows |
| Body | `.body`, with supporting text in `.subheadline` and `.secondary` |
| Eyebrow and metadata | `.eyebrowStyle()`, which is `.caption.weight(.semibold)` in `.secondary` |
| Numbers that change | Add `.monospacedDigit()` |

## Shape and spacing

- Radii (`Theme.Radius`): `small` 12 for inputs and thumbnails, `tile` 14, `board` 16, `card` 22, and `floating` 28. Always use continuous corners.
- Spacing (`Theme.Spacing`): 4, 8, 12, 16, 20, and 28. Screens pad by `l` (20). Sections are `xl` (28) apart. Cards pad by `m` (16).
- Capsules are for buttons, chips, badges, and progress bars.
- Content is capped at 720 points wide, and boards at 560 points, so iPad layouts stay readable.

## Layout

FreeMate should feel like an app Apple would ship: native components first, one clear action per screen, and nothing that does not help the learner right now.

- **Lists are native.** Browsing screens (Learn, Openings, Practice, Review, course and opening details, Settings) are `List` with `.insetGrouped` style. Rows are `IconRow`: a small colored icon, a title, an optional subtitle, and an optional trailing value. Section footers explain, so rows do not have to.
- **Large titles only on tab roots.** Detail screens use inline titles.
- **Search, not filters.** Use `.searchable`. Do not add filter chips.
- **Focused screens hide the tab bar.** The lesson player, trainers, tutorials, the game, puzzles, and the free board call `.focusedScreen()`. Their actions go in a bottom toolbar (icons with labels for VoiceOver) or a single floating button at the bottom, never in a stack of buttons under the board.
- **Settings lives on Today.** The gear appears only there.
- **Cards are for the one thing that matters.** Today's Continue card, a warning, or a result. Use `.cardStyle()` sparingly.
- **No small labels above titles, and no marketing copy.**

## Components

| Need | Use |
| --- | --- |
| A list row | `IconRow(title:subtitle:systemImage:color:)` with an optional trailing view |
| A card | `.cardStyle()` |
| Main and secondary actions | `.borderedProminent` and `.bordered` with `.buttonBorderShape(.capsule)`, or `.primaryButtonStyle()` and `.secondaryButtonStyle()` |
| A pair of actions | `ActionButtons`, which sits side by side when there is room and stacks full width when there is not |
| Progress | `ProgressView(value:)` tinted with `Theme.accent`, `CapsuleProgressBar`, or `ProgressRing` |
| A state | `StatusBadge(text:systemImage:tint:)` |
| An icon | `IconTile(systemImage:color:size:)` |
| A focused screen | `.focusedScreen()` |
| A board | `ModernBoardView` for interaction and `BoardThumbnail` for previews. Never draw a board another way. |
| Tappable cards | `.buttonStyle(PressableCardStyle())` |

## Motion and feedback

- State changes use `DesignMotion.spring` (`.spring(response: 0.4, dampingFraction: 0.8)`). Pieces use `DesignMotion.piece`.
- Mistakes get `ShakeEffect` and `Haptics.error()`. Selections and correct moves get `Haptics.light()`. Big completions get `Haptics.success()`.
- Respect Reduce Motion: no shakes, pulsing, or confetti when it is on.

## Appearance

The app follows the system's light or dark mode. Settings has an Appearance choice (System, Light, or Dark), stored as `freemate.appearance` and applied in `FreeMateIOSApp`. Every token adapts, so check new screens in both modes.
