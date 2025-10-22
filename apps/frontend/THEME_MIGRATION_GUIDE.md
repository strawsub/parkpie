# Theme Migration Guide

**Date:** October 21, 2025
**Status:** Priority 1 - Tasks 1-3 Complete ✅

## What We've Done

### ✅ Task 1: Created Centralized Theme System

Created 3 new files in `lib/theme/`:

1. **`app_colors.dart`** - All color constants
   - Primary: `#7FAC58` (green)
   - Error: `#FF4757` (red)
   - Semantic colors (success, warning, info)
   - Text colors (primary, secondary, tertiary, disabled)
   - Surface/background colors
   - Shadow/overlay opacity variants

2. **`spacing.dart`** - Standardized spacing & radii
   - 8pt grid system (4, 8, 12, 16, 20, 24, 32, 40, 60)
   - Border radii (4, 8, 12, 16, 20, 24)
   - Touch target minimums (48dp, 56dp)

3. **`app_theme.dart`** - Complete `ThemeData` configuration
   - Material 3 enabled (`useMaterial3: true`)
   - `ColorScheme.light()` with all primary/error/surface colors
   - Typography system (15 text styles using Plus Jakarta Sans)
   - Button themes (Elevated, Filled, Outlined, Text)
   - Component themes (Card, Input, Dialog, BottomSheet, Chip, etc.)

### ✅ Task 2: Enabled Material 3

Modified `lib/main.dart`:
```dart
MaterialApp(
  theme: AppTheme.lightTheme,  // ← Added this line
  // ...
)
```

Material 3 is now active with modern components like:
- NavigationBar (to replace BottomNavigationBar)
- FilledButton, FilledTonalButton
- Dynamic color support
- Updated elevation/shadows

### ✅ Task 3: Migrated `tab_bar.dart` as Example

**Before** (inline colors):
```dart
selectedItemColor: const Color(0xFF7FAC58),
unselectedItemColor: Colors.grey.shade600,
```

**After** (theme-based):
```dart
final theme = Theme.of(context);
final colorScheme = theme.colorScheme;

selectedItemColor: colorScheme.primary,
unselectedItemColor: theme.textTheme.bodySmall?.color,
```

**Result:** No more hard-coded colors in `tab_bar.dart`! All colors now come from the centralized theme.

---

## How to Use the New Theme

### Example 1: Using Colors

**❌ OLD WAY (Don't do this)**
```dart
Container(
  color: const Color(0xFF7FAC58),  // Hard-coded!
  child: Text(
    'Hello',
    style: TextStyle(color: Colors.grey.shade600),  // Inline color!
  ),
)
```

**✅ NEW WAY (Do this)**
```dart
Container(
  color: Theme.of(context).colorScheme.primary,
  // OR import the colors file:
  // color: AppColors.primary,
  child: Text(
    'Hello',
    style: Theme.of(context).textTheme.bodyMedium,  // Uses theme!
  ),
)
```

### Example 2: Using Spacing

**❌ OLD WAY**
```dart
EdgeInsets.symmetric(horizontal: 24, vertical: 16)  // Magic numbers!
SizedBox(height: 20)
```

**✅ NEW WAY**
```dart
import 'package:frontend/theme/spacing.dart';

EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.md)
SizedBox(height: Spacing.lg)
```

### Example 3: Using Buttons

Buttons now automatically use the theme! No styling needed:

```dart
// ElevatedButton is automatically green with white text
ElevatedButton(
  onPressed: () {},
  child: Text('Start Timer'),  // Theme applies automatically
)

// OutlinedButton is automatically styled
OutlinedButton(
  onPressed: () {},
  child: Text('Cancel'),
)
```

### Example 4: Using Border Radius

**❌ OLD WAY**
```dart
BorderRadius.circular(12)  // Magic number!
```

**✅ NEW WAY**
```dart
import 'package:frontend/theme/spacing.dart';

BorderRadius.circular(Radii.card)  // 12
BorderRadius.circular(Radii.button)  // 12
BorderRadius.circular(Radii.modal)  // 24
```

---

## Migration Checklist for Remaining Files

We migrated `tab_bar.dart` as an example. You still need to migrate **41 more inline `Color(0x...)` usages** across these files:

### High Priority (Core Screens)
- [ ] `lib/features/camera/camera_screen.dart` (11 usages)
- [ ] `lib/features/timer/timer_screen.dart` (15 usages)
- [ ] `lib/widgets/parking_detected_bottom_sheet.dart` (3 usages)

### Medium Priority
- [ ] `lib/widgets/parking_zone_carousel.dart` (1 usage)
- [ ] `lib/features/settings/language/language_selection_page.dart` (2 usages)
- [ ] `lib/features/map/parking_info/parking_info_screen.dart` (1 usage)
- [ ] `lib/features/map/filter/filter_panel.dart` (3 usages)
- [ ] `lib/features/map/map_screen/map_screen_area.dart` (3 usages)
- [ ] `lib/features/map/map_screen/map_screen_ui.dart` (5 usages)

### Migration Pattern

For each file:

1. **Add import at top:**
   ```dart
   import 'package:frontend/theme/app_colors.dart';
   import 'package:frontend/theme/spacing.dart';
   ```

2. **Get theme in build method:**
   ```dart
   final theme = Theme.of(context);
   final colorScheme = theme.colorScheme;
   ```

3. **Replace color literals:**
   - `Color(0xFF7FAC58)` → `colorScheme.primary` or `AppColors.primary`
   - `Color(0xFFFF4757)` → `colorScheme.error` or `AppColors.error`
   - `Colors.white` → `colorScheme.surface` or `AppColors.surface`
   - `Colors.grey.shade600` → `AppColors.textSecondary`
   - `Colors.black.withValues(alpha: 0.5)` → `AppColors.overlay`

4. **Replace text styles:**
   - `TextStyle(fontSize: 24, fontWeight: FontWeight.bold)` → `theme.textTheme.displaySmall`
   - `TextStyle(fontSize: 16, fontWeight: FontWeight.w600)` → `theme.textTheme.titleMedium`
   - `TextStyle(fontSize: 14)` → `theme.textTheme.bodyMedium`

5. **Replace spacing:**
   - `EdgeInsets.all(16)` → `EdgeInsets.all(Spacing.md)`
   - `SizedBox(height: 24)` → `SizedBox(height: Spacing.xl)`
   - `BorderRadius.circular(12)` → `BorderRadius.circular(Radii.card)`

---

## Testing the Theme

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Verify colors match:**
   - Bottom nav icons should still be green when selected
   - Text should still be readable
   - Buttons should have correct colors

3. **Test dark mode support (future):**
   Once all colors are migrated, we can easily add a dark theme:
   ```dart
   MaterialApp(
     theme: AppTheme.lightTheme,
     darkTheme: AppTheme.darkTheme,  // Just add this!
     themeMode: ThemeMode.system,
   )
   ```

---

## Benefits of This Approach

✅ **Consistency** - All screens use the same colors/spacing
✅ **Maintainability** - Change primary color once in `app_colors.dart`, affects entire app
✅ **Dark mode ready** - Easy to add `AppTheme.darkTheme` later
✅ **Accessibility** - Centralized contrast ratios, touch targets
✅ **Material 3** - Modern components with better UX
✅ **Type safety** - No typos in hex codes

---

## Next Steps

Continue with **Priority 1, Tasks 4-5**:

1. **Fix touch target sizes** - Ensure all buttons are ≥48dp (already done in theme!)
2. **Add Semantics labels** - For screen reader accessibility
3. **Link Settings screens** - Add menu to access language/privacy pages

Then move to **Priority 2**:
- Migrate all remaining inline colors (41 usages)
- Add skeleton loaders
- Build onboarding flow
- Migrate to GoRouter for deep linking

---

## Questions?

If you encounter issues or have questions about migrating specific components, refer to:
- `lib/widgets/tab_bar.dart` - Example of a fully migrated component
- `lib/theme/app_theme.dart` - All available theme styles
- Flutter Material 3 docs: https://m3.material.io/
