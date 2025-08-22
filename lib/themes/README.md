# App Theme System

This directory contains the comprehensive theme system for the Forward Billing App.

## Files

- `light_theme.dart` - Complete light theme with all colors, styles, and decorations
- `dark_theme.dart` - Complete dark theme with all colors, styles, and decorations  
- `app_theme.dart` - Main theme manager with helper methods

## Usage

### Basic Usage

```dart
import 'package:your_app/themes/app_theme.dart';

// Get theme data
ThemeData lightTheme = LightTheme.themeData;
ThemeData darkTheme = DarkTheme.themeData;

// In MaterialApp
MaterialApp(
  theme: LightTheme.themeData,
  darkTheme: DarkTheme.themeData,
  // ...
)
```

### Using Theme Helper Methods

```dart
// Get colors based on current theme context
Color primaryColor = AppTheme.getPrimaryColor(context);
Color backgroundColor = AppTheme.getBackgroundColor(context);
Color textColor = AppTheme.getTextColor(context);
Color cursorColor = AppTheme.getCursorColor(context);

// Get decorations
BoxDecoration cardDecoration = AppTheme.getCardDecoration(context);
InputDecorationTheme inputDecorationTheme = AppTheme.getInputDecorationTheme(context);

// Get standardized form elements
InputDecoration inputDecoration = AppTheme.getStandardInputDecoration(
  context,
  labelText: 'Field Label',
  hintText: 'Enter value',
  prefixIcon: Icons.person,
);
ButtonStyle saveButton = AppTheme.getStandardSaveButtonStyle(context);
ButtonStyle cancelButton = AppTheme.getStandardCancelButtonStyle(context);

// Get button styles
ButtonStyle primaryButton = AppTheme.getPrimaryButtonStyle(context);
ButtonStyle secondaryButton = AppTheme.getSecondaryButtonStyle(context);

// Check theme mode
bool isDark = AppTheme.isDarkMode(context);
```

### Direct Access to Theme Classes

```dart
// Access colors directly
Color primaryBlue = LightTheme.primaryBlue;
Color darkBackground = DarkTheme.scaffoldBackground;

// Access text styles
TextStyle heading = LightTheme.headingLarge;
TextStyle bodyText = DarkTheme.bodyMedium;

// Access decorations
BoxDecoration card = LightTheme.cardDecoration;
InputDecorationTheme input = DarkTheme.inputDecorationTheme;

// Access standardized form elements
InputDecoration inputDecoration = LightTheme.getStandardInputDecoration(
  labelText: 'Field Label',
  hintText: 'Enter value',
  prefixIcon: Icons.person,
);
ButtonStyle saveButton = LightTheme.standardSaveButtonStyle;
ButtonStyle cancelButton = LightTheme.standardCancelButtonStyle;
```

## Color System

### Light Theme Colors
- **Primary**: `#1976D2` (Blue)
- **Background**: `#FFFFFF` (White)
- **Card**: `#FFFFFF` (White)
- **Text**: `#1A1A1A` (Dark Gray)
- **Border**: `#E0E0E0` (Light Gray)

### Dark Theme Colors
- **Primary**: `#1976D2` (Blue)
- **Background**: `#0A2342` (Dark Blue)
- **Card**: `#1A2233` (Dark Gray)
- **Text**: `#FFFFFF` (White)
- **Border**: `#2C3E50` (Dark Gray)

## Text Styles

Both themes include comprehensive text styles:
- `headingLarge`, `headingMedium`, `headingSmall`
- `titleLarge`, `titleMedium`, `titleSmall`
- `bodyLarge`, `bodyMedium`, `bodySmall`
- `labelLarge`, `labelMedium`, `labelSmall`

## Components

### Buttons
- `primaryButtonStyle` - Filled primary button
- `secondaryButtonStyle` - Outlined secondary button
- `textButtonStyle` - Text button

### Input Fields
- `inputDecorationTheme` - Standard input field styling
- `getStandardInputDecoration()` - Standardized input decoration for forms
- `cursorColor` - Theme-aware cursor color
- `standardSaveButtonStyle` - Standard save button styling
- `standardCancelButtonStyle` - Standard cancel button styling

### Cards
- `cardDecoration` - Standard card with border
- `elevatedCardDecoration` - Card with shadow

## Migration from Old System

The old theme constants in `lib/utils/app_theme.dart` are still available for backward compatibility, but new code should use the new theme system.

### Old Way
```dart
Color color = kBlue;
TextStyle style = kHeadingStyle;
```

### New Way
```dart
Color color = AppTheme.getPrimaryColor(context);
TextStyle style = AppTheme.getTextTheme(context).headlineLarge;
```

## Best Practices

1. **Always use context-aware methods** when possible to ensure proper theme switching
2. **Use direct access** for static values that don't depend on theme mode
3. **Prefer the new system** over legacy constants for new code
4. **Test both themes** to ensure proper contrast and readability 