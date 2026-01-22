# ROCIs Tasks - Theme Documentation

## Overview

This document describes the complete theming system for the ROCIs Tasks application. Use this as a reference to replicate the app's visual design, color scheme, typography, and component styling in any project or when instructing an AI to create similar theming.

---

## Design Philosophy

### Core Principles

- **Modern & Premium**: Clean, sophisticated design with subtle animations and micro-interactions
- **Material 3**: Full Material Design 3 compliance with dynamic color support
- **Adaptive Theming**: Support for light mode, dark mode, and AMOLED black mode
- **Dynamic Colors**: Optional Material You dynamic theming based on system colors
- **Accessibility**: High contrast ratios, semantic labeling, and screen reader support
- **Minimalist Elegance**: Generous use of rounded corners, soft shadows, and smooth transitions

---

## Color Palette

### Primary Colors

```dart
Primary Color: #6366F1 (Modern Indigo)
Secondary Color: #10B981 (Emerald Green)
Accent Color: #F59E0B (Amber)
Error Color: #EF4444 (Red)
```

### Light Theme Colors

```dart
Background: #F8FAFC (Slate 50)
Surface: #FFFFFF (White)
Text: #0F172A (Slate 900)
```

### Dark Theme Colors

```dart
Background: #0F172A (Slate 900)
Surface: #1E293B (Slate 800)
Text: #F8FAFC (Slate 50)
```

### AMOLED Theme

```dart
Background: #000000 (Pure Black)
Surface: #000000 (Pure Black)
Text: Follows Material 3 color scheme
```

### Material 3 Color Roles

The app uses Material 3's dynamic color system, which generates **a complete color palette from the seed color**. When dynamic colors are enabled (Material You on Android 12+), these are replaced with system-derived colors from the user's wallpaper.

#### Generated from Seed Color (#6366F1)

**Light Theme - Complete Color Scheme:**

```dart
Seed Color: #6366F1 (Indigo)

// Primary Colors
primary: Vibrant indigo (auto-generated from seed)
onPrimary: White or very light shade for text on primary
primaryContainer: Light indigo tint for containers
onPrimaryContainer: Dark indigo shade for text on light containers

// Secondary Colors
secondary: Complementary color (auto-generated)
onSecondary: Contrasting text color for secondary
secondaryContainer: Light secondary tint
onSecondaryContainer: Dark secondary shade for text

// Tertiary Colors
tertiary: Accent color (auto-generated, typically opposite hue)
onTertiary: Contrasting text color for tertiary
tertiaryContainer: Light tertiary tint
onTertiaryContainer: Dark tertiary shade for text

// Error Colors
error: #EF4444 (Red) or Material default
onError: White
errorContainer: Light red/pink tint
onErrorContainer: Dark red shade

// Surface & Background
surface: #FFFFFF (default) or from dynamic colors
onSurface: #0F172A (dark text for readability)
surfaceVariant: Subtle gray/tinted surface
onSurfaceVariant: Medium emphasis text (60-70% opacity)

// Surface Containers (Material 3 emphasis levels)
surfaceContainerLowest: Lightest surface level
surfaceContainerLow: Light surface (used for cards)
surfaceContainer: Default container surface
surfaceContainerHigh: Elevated surface
surfaceContainerHighest: Highest surface elevation

// Surface Tint & Effects
surfaceTint: Primary color (for elevation tinting)
shadow: Black with low opacity
scrim: Black overlay for dialogs/sheets

// Outline & Borders
outline: Medium emphasis borders/dividers
outlineVariant: Low emphasis borders (subtle)

// Inverse Colors (for dark-on-light surfaces in light theme)
inverseSurface: Dark surface color
onInverseSurface: Light text on inverse surface
inversePrimary: Adjusted primary for inverse surfaces
```

**Dark Theme - Complete Color Scheme:**

```dart
Seed Color: #6366F1 (Indigo)

// Primary Colors - Brighter for dark backgrounds
primary: Lighter, more vibrant indigo than light mode
onPrimary: Darker indigo for contrast
primaryContainer: Darker indigo container (#1E293B range)
onPrimaryContainer: Lighter indigo text

// Secondary Colors - Adjusted for dark mode
secondary: Brighter than light mode version
onSecondary: Darker for proper contrast
secondaryContainer: Darker container
onSecondaryContainer: Lighter text

// Tertiary Colors - Adjusted for dark mode
tertiary: Brighter accent color
onTertiary: Darker for contrast
tertiaryContainer: Darker container
onTertiaryContainer: Lighter text

// Error Colors
error: Bright red (lighter than light mode)
onError: Darker for contrast
errorContainer: Dark red container
onErrorContainer: Light red/pink text

// Surface & Background
surface: #1E293B (default) or from dynamic colors
  → AMOLED Override: #000000 (Pure Black)
onSurface: #F8FAFC (light text)
surfaceVariant: Slightly lighter/tinted surface
onSurfaceVariant: Medium emphasis light text

// Surface Containers
surfaceContainerLowest: Darkest surface level
surfaceContainerLow: Dark surface (used for cards)
  → AMOLED Override: #000000 (Pure Black)
surfaceContainer: Default dark container
surfaceContainerHigh: Lighter dark surface
surfaceContainerHighest: Lightest dark surface

// Surface Tint & Effects
surfaceTint: Primary color
shadow: Black
scrim: Black overlay

// Outline & Borders
outline: Medium emphasis borders (lighter than light mode)
outlineVariant: Low emphasis borders

// Inverse Colors
inverseSurface: Light surface
onInverseSurface: Dark text
inversePrimary: Adjusted primary for light surfaces
```

#### Dynamic Color Behavior

**When Dynamic Colors are Enabled** (`useMaterialTheme: true`):

- Android 12+ devices: Colors derive from user's wallpaper via Material You
- Seed color ignored, system provides full color scheme
- Maintains accessibility contrast ratios automatically
- All color roles update based on wallpaper

**When Dynamic Colors are Disabled** (`useMaterialTheme: false`):

- Uses `ColorScheme.fromSeed(seedColor: #6366F1)`
- Generates consistent brand colors across all devices
- All color roles computed from indigo seed color
- Predictable, unchanging appearance

#### AMOLED Mode Color Overrides

When `useAmoledTheme: true` in dark mode:

```dart
surface: #000000 (overrides generated dark surface)
surfaceContainerLow: #000000 (overrides generated container)
cards: elevation = 0, border = rgba(255, 255, 255, 0.24)
```

All other color roles remain from Material 3 generation but applied over pure black.

### Priority Indicator Colors

```dart
High Priority: #FF5252 (Red Accent)
Medium Priority: #FFAB40 (Orange Accent)
Low Priority: #69F0AE (Green Accent)
```

### Semantic Colors

- **Success/Completed**: Derived from category color or primary color
- **Disabled**: Theme's disabled color (gray tone)
- **Border Light**: rgba(158, 158, 158, 0.1)
- **Border Dark**: rgba(255, 255, 255, 0.05)

---

## Typography

### Font Family

**Primary Font**: [Google Fonts - Outfit](https://fonts.google.com/specimen/Outfit)

```dart
import 'package:google_fonts/google_fonts.dart';

textTheme: GoogleFonts.outfitTextTheme(
  ThemeData.light().textTheme,
).apply(
  bodyColor: colorScheme.onSurface,
  displayColor: colorScheme.onSurface,
)
```

### Text Styles

#### App Bar Title

```dart
fontSize: 20
fontWeight: FontWeight.w600 (Semi-Bold)
color: onSurface
```

#### Task Title

```dart
fontSize: 16 (titleMedium)
fontWeight: FontWeight.bold
color: onSurface (or disabled color if completed)
textDecoration: lineThrough (if completed)
```

#### Task Description

```dart
fontSize: 12 (bodySmall)
color: onSurface with 60% opacity
lineHeight: 1.4
maxLines: 2
overflow: ellipsis
```

#### Chip Labels

```dart
fontSize: 11
fontWeight: FontWeight.bold
color: Matches chip color
fontFamily: Outfit
```

#### Loading/Error Text

```dart
fontSize: 28 (app name)
fontSize: 16 (subtitle)
fontWeight: FontWeight.bold
letterSpacing: 1.2
```

---

## Component Styling

### Cards (Task Tiles)

#### Container Properties

```dart
margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8)
borderRadius: BorderRadius.circular(24)
border: BorderSide(
  color: light ? rgba(158, 158, 158, 0.1) : rgba(255, 255, 255, 0.05)
)
boxShadow: [
  BoxShadow(
    color: rgba(0, 0, 0, 0.03),
    blurRadius: 10,
    offset: Offset(0, 4),
  )
]
```

#### AMOLED Card Styling

```dart
elevation: 0
borderRadius: BorderRadius.circular(16)
border: BorderSide(color: rgba(255, 255, 255, 0.24))
```

#### Standard Card Styling

```dart
elevation: 2
borderRadius: BorderRadius.circular(16)
margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16)
```

### App Bar

```dart
backgroundColor: scheme.surface (or background for AMOLED)
elevation: 0
centerTitle: true
iconTheme: IconThemeData(color: scheme.onSurface)
titleTextStyle: TextStyle(
  color: scheme.onSurface,
  fontSize: 20,
  fontWeight: FontWeight.w600,
)
```

### Floating Action Button

```dart
backgroundColor: scheme.primary
foregroundColor: scheme.onPrimary
```

### Checkbox/Toggle (Custom)

```dart
width: 28
height: 28
borderRadius: BorderRadius.circular(10)
border: Border.all(
  color: category color or primary with 50% opacity,
  width: 2,
)
checked:
  backgroundColor: category color or primary
  icon: Icons.check (white, size 18)
unchecked:
  backgroundColor: transparent
```

### Chips (Category/Time Indicators)

```dart
padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)
borderRadius: BorderRadius.circular(8)
backgroundColor: color with 10% opacity
```

Chip Contents:

```dart
Icon: size 12, color matches chip color
Text: fontSize 11, fontWeight bold, color matches chip color
spacing: 4px between icon and text
```

### Input Fields

```dart
borderRadius: BorderRadius.circular(16)
border: none (default), 2px primary color (focused)
filled: true
fillColor: light ? rgba(158, 158, 158, 0.05) : rgba(255, 255, 255, 0.05)
contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16)
labelStyle: Outfit font, 60% opacity
prefixIcon: size 22
```

### Priority Indicator

```dart
width: 10
height: 10
shape: circle
color: High/Medium/Low priority color
boxShadow: [
  BoxShadow(
    color: priority color with 40% opacity,
    blurRadius: 6,
    spreadRadius: 1,
  )
]
margin: EdgeInsets.only(bottom: 4)
```

### Category Color Edge

```dart
width: 6
color: category.colorValue
positioned: left edge of card
height: full card height (IntrinsicHeight)
```

### Dismissible Background (Swipe to Delete)

```dart
margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8)
borderRadius: BorderRadius.circular(24)
color: error color with 90% opacity
alignment: Alignment.centerLeft
padding: EdgeInsets.symmetric(horizontal: 24)
icon: Icons.delete_outline (white, size 28)
  - positioned at both left and right edges
```

---

## Layout & Spacing

### Standard Spacing Scale

```dart
Extra Small: 4px
Small: 8px
Medium: 12px
Large: 16px
Extra Large: 24px
XXL: 32px
```

### Task Tile Layout

```dart
Outer margin: vertical 4, horizontal 8
Inner padding: horizontal 16, vertical 10
Checkbox margin (top): 2px
Checkbox to content: 16px
Content to pin button: 16px
Row items spacing: 8px between chips
Description padding (top): 8px
Metadata padding (top): 12px
```

### Border Radius Scale

```dart
Small: 8px (chips)
Medium: 10px (checkbox)
Large: 16px (cards in theme, input fields)
Extra Large: 24px (task tiles)
```

---

## Animations & Transitions

### Checkbox Toggle

```dart
duration: Duration(milliseconds: 300)
animates: width, height, backgroundColor, border
```

### General Guidelines

- Use smooth, subtle animations
- Prefer 200-300ms durations for micro-interactions
- Material motion principles for page transitions
- Maintain 60fps performance

---

## Circular Task Chart Widget

### Purpose

Displays task distribution as a circular progress chart (used in notifications and dashboards).

### Properties

```dart
high: int (number of high priority tasks)
medium: int (number of medium priority tasks)
low: int (number of low priority tasks)
size: double (default 100)
```

### Visual Specifications

```dart
strokeWidth: 12% of size
strokeCap: StrokeCap.round
startAngle: -π/2 (top of circle)

Colors:
  High Priority: #FF5252
  Medium Priority: #FFAB40
  Low Priority: #69F0AE
  Empty State: #EEEEEE

Segment Order (clockwise from top):
  1. Low priority (green)
  2. Medium priority (orange)
  3. High priority (red)
```

### Edge Cases

- If total = 0: Draw a gray empty circle
- If only one priority has tasks: Draw a complete circle in that priority's color
- Filters out zero-value segments before drawing

---

## Theme Service Features

### Theme Modes

```dart
enum ThemeMode {
  system,  // Follows system theme
  light,   // Always light
  dark,    // Always dark
}
```

### Additional Settings

```dart
useMaterialTheme: bool (default: true)
  - Enables/disables Material You dynamic colors

useAmoledTheme: bool (default: false)
  - Enables pure black background for AMOLED displays

use24HourFormat: bool (default: false)
  - Controls time format in UI

locale: Locale? (default: null/system)
  - Supports: en (English), he (Hebrew)
  - Includes RTL support for Hebrew
```

### Storage

All theme preferences are persisted using `SharedPreferences`:

```dart
'theme_mode' -> int (ThemeMode index)
'use_material_theme' -> bool
'use_amoled_theme' -> bool
'use_24h_format' -> bool
'language_code' -> String
```

---

## Material Design 3 Integration

### Color Scheme Generation

```dart
ColorScheme.fromSeed(
  seedColor: #6366F1,
  brightness: Brightness.light/dark,
)
```

### Dynamic Color Support

```dart
import 'package:dynamic_color/dynamic_color.dart';

// Conditionally use system dynamic colors
DynamicColorBuilder(
  builder: (lightDynamic, darkDynamic) {
    return MaterialApp(
      theme: createLightTheme(
        useMaterialTheme ? lightDynamic : null
      ),
      darkTheme: createDarkTheme(
        useMaterialTheme ? darkDynamic : null
      ),
    );
  },
)
```

### Surface Variants

```dart
Light Theme:
  surfaceContainerLow: Auto-generated from color scheme

Dark Theme:
  surfaceContainerLow: Auto-generated from color scheme
  (or pure black if AMOLED mode enabled)
```

---

## Loading & Error States

### Loading Screen

```dart
backgroundColor: Colors.black
centerContent: true

Column:
  - CircularProgressIndicator(color: white)
  - SizedBox(height: 24)
  - Text("ROCI's Tasks")
    fontSize: 28
    fontWeight: bold
    letterSpacing: 1.2
    color: white
  - Text("Dotting the i's and crossing the t's")
    fontSize: 16
    letterSpacing: 1.2
    color: white
```

### Error Screen

```dart
backgroundColor: Colors.black
centerContent: true
padding: 32px

Column:
  - Icon(Icons.error_outline)
    color: red
    size: 80
  - SizedBox(height: 24)
  - Text("CRITICAL ERROR")
    fontSize: 22
    fontWeight: bold
    color: white
  - SizedBox(height: 16)
  - Text(error message)
    fontSize: 16
    color: redAccent
    textAlign: center
```

---

## Accessibility Features

### Semantic Labels

All interactive elements include semantic labels:

```dart
Checkbox:
  - "Mark task as complete" / "Mark task as incomplete"

Pin Button:
  - "Pin task" / "Unpin task"

Task Tile:
  - "Task: {title}"
  - Hint: "Double tap to edit task details"
```

### Touch Targets

- Minimum touch target: 48x48 dp (Material guidelines)
- Icon buttons use appropriate padding for accessibility
- Swipe gestures have generous detection areas

---

## Localization

### Supported Languages

- English (en)
- Hebrew (he)

### Text Direction

Automatically adjusts based on language:

```dart
RTL Support: Hebrew text automatically flows right-to-left
LTR Support: English text flows left-to-right
```

### Localization Delegates

```dart
localizationsDelegates: [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
]
```

---

## Implementation Checklist

When recreating this theme in a new project:

- [ ] Install dependencies: `google_fonts`, `dynamic_color`, `shared_preferences`
- [ ] Create `AppTheme` class with primary color palette
- [ ] Implement `ThemeService` for theme management
- [ ] Set up light/dark theme generation with Material 3
- [ ] Add AMOLED theme support
- [ ] Configure Google Fonts (Outfit)
- [ ] Create custom widgets: `CircularTaskChart`, input decorations
- [ ] Implement card styling with rounded corners and shadows
- [ ] Add priority color indicators
- [ ] Set up checkbox/toggle styling
- [ ] Configure chip styling for categories/metadata
- [ ] Implement loading and error states
- [ ] Add semantic labels for accessibility
- [ ] Test in light, dark, and AMOLED modes
- [ ] Verify dynamic color support works
- [ ] Test RTL layout for Hebrew

---

## Code Dependencies

### Required Packages

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^latest
  dynamic_color: ^latest
  shared_preferences: ^latest
  provider: ^latest
```

---

## Additional Notes

### Performance Considerations

- Google Fonts are cached after first download
- Theme changes notify listeners and rebuild efficiently
- Animations use const durations for performance
- CustomPainter for circular chart minimizes redraws

### Customization Points

When adapting this theme, the easiest customization points are:

1. **Seed Color**: Change `#6366F1` to match your brand
2. **Font Family**: Replace Outfit with your preferred typeface
3. **Border Radius**: Adjust the `24px` tile radius for different feels
4. **Priority Colors**: Modify red/orange/green to match your color system
5. **Spacing Scale**: Adjust the base 8px scale if needed

---

_This theme documentation was created for the ROCIs Tasks application. Last updated: January 2026_
