# Theme & Style Guide - ROCI's Tasks

This document summarizes the complete design system, typography, colors, component specifications, and behavioral styling rules of **ROCI's Tasks**. It is designed to be fed directly into an AI system to guide it in replicating the exact visual identity and UI feel of the application.

---

## 🎨 Design Philosophy & Aesthetic
ROCI's Tasks uses a **premium, minimalist, and ultra-modern aesthetic** that relies on:
- **Glassmorphism** (soft translucent backdrops, thin subtle borders, and blur effects).
- **Deep space dark mode** (sleek slate backgrounds) and optional pure black AMOLED styling.
- **Vibrant accent gradients** that pop against dark backdrops.
- **Soft organic edges** (highly rounded corners) for interactive elements.
- **Fluid transitions** (smooth micro-animations and staggered entries).

---

## 🎨 Color System (Palette Tokens)

### Core Branding Colors
- **Primary Color**: `#6366F1` (Modern Indigo) - Used for primary actions, focused states, and accent branding.
- **Secondary Color**: `#10B981` (Emerald Green) - Used for success states, completed tasks, and secondary accents.
- **Accent Color**: `#F59E0B` (Amber Orange) - Used for warnings, highlighted states, and medium priority indicators.
- **Error Color**: `#EF4444` (Vibrant Red) - Used for errors, delete buttons, and high priority indicators.

### Task Priority Color Mappings
- **High Priority**: `#FF5252` (Vibrant Red Accent)
- **Medium Priority**: `#FFAB40` (Bright Orange Accent)
- **Low Priority**: `#69F0AE` (Mint Green Accent)
- **Empty / Inactive**: `#EEEEEE` (Light Grey) or transparent container border variations

### Platform / Theme Contexts

#### 1. Light Mode
- **Scaffold Background**: `#F8FAFC` (Clean, off-white slate)
- **Cards & Surface**: `#FFFFFF` (Pure white)
- **Text & Foreground**: `#0F172A` (Slate Dark)
- **Surface Container Low**: `#F1F5F9` (Light Slate Grey)

#### 2. Slate Dark Mode (Default Dark)
- **Scaffold Background**: `#0F172A` (Deep Slate Dark)
- **Cards & Surface**: `#1E293B` (Medium Slate Grey)
- **Text & Foreground**: `#F8FAFC` (Slate Light)
- **Surface Container Low**: `#1E293B`

#### 3. AMOLED Dark Mode
- **Scaffold Background**: `#000000` (True Black)
- **Cards & Surface**: `#000000` (True Black)
- **Cards Border**: `rgba(255, 255, 255, 0.15)` (Thin white border, no elevation)
- **Text & Foreground**: `#F8FAFC`

---

## ✍️ Typography
- **Primary Font Family**: `'Outfit'` (via Google Fonts or modern web fallback)
- **Fallback Font Stack**: `'Outfit', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif`
- **Text Attributes**:
  - **App Title**: `fontSize: 28px`, `fontWeight: 700`, `letterSpacing: 1.2px`
  - **Screen Header**: `fontSize: 20px`, `fontWeight: 600`, `letterSpacing: normal`
  - **Body / Labels**: `fontSize: 16px` to `18px`, `letterSpacing: normal`

---

## 🧩 Key Component Specifications

### 1. Glass Container (`GlassContainer`)
The signature container of the app. It dynamically switches between solid cards and translucent glass elements.

#### Glassmorphism Specification:
- **Translucent Backdrop Blending (Tint)**:
  - **Light Mode**: Linear interpolation (`lerp`) of `#FFFFFF` (White) and the primary/category color at **12% (0.12)** blend ratio.
  - **Dark Mode**: Linear interpolation (`lerp`) of `#151824` (Deep Navy-Black) and the primary/category color at **18% (0.18)** blend ratio.
- **Glass Opacity**: Default **15% (0.15)** backdrop fill, increasing by **10% (0.10)** when the container is in a selected/active state.
- **Glass Borders**:
  - Thin **1.0px** solid border (widens to **2.0px** when selected).
  - Border is tinted with the primary/category color.
  - Border opacity: **15% (0.15)** in dark mode, **10% (0.10)** in light mode.
- **Corner Radius**: High rounded corners, default `BorderRadius.circular(24.0)`.
- **Backdrop Filter (Blur)**: `ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0)` for realistic refraction.
  *Note: Blur is disabled on Web builds (`!kIsWeb`) to maximize scrolling/rendering frame rate.*
- **Fallback (Glassmorphism Inactive)**:
  - Background color is `theme.colorScheme.surfaceContainerLow` with no border and standard shadows.

### 2. Input Fields (`SharedInputDecorations`)
Input fields are rounded, bordered only on focus, and rely on subtle container fills.
- **Borders**: Completely hidden (`BorderSide.none`) for default states.
- **Focused Border**: **2.0px** solid border matching the primary color (`#6366F1`).
- **Corner Radius**: `BorderRadius.circular(16.0)`.
- **Fills**:
  - **Light Mode**: `rgba(128, 128, 128, 0.05)` (5% grey fill).
  - **Dark Mode**: `rgba(255, 255, 255, 0.05)` (5% white fill).
- **Padding**: Large internal spacing: `horizontal: 20px, vertical: 16px`.

### 3. Cards & Panels
- **Default Card Corner Radius**: `BorderRadius.circular(16.0)` or `24.0` (organic and smooth).
- **Elevations & Shadows**:
  - Low elevations: `elevation: 2.0` in light mode.
  - No shadows in AMOLED mode, replaced by a subtle `rgba(255, 255, 255, 0.15)` border.

### 4. Circular Progress & Segmented Charts (`CircularTaskChart`)
- **Visuals**: Drawn using stroke circles with rounded end caps (`StrokeCap.round`).
- **Thickness**: Segment stroke width is exactly **12%** of the chart's total bounding size.
- **Empty State**: Rendered as a light grey (`#EEEEEE`) inactive stroke.

---

## 🎬 Animations & Micro-interactions
- **Staggered Entries**: Lists on mobile/desktop use a vertical entry animation:
  - Slide up animation from a `50.0px` offset.
  - Duration: `375ms`.
  - Fade-in animation starting from opacity `0.0`.
  - Staggered delay per list index.
  *Note: For performance optimization, staggered list animations are disabled on the Web version, rendering list items directly.*
- **Tactile Feedback**: Medium impact haptic feedback (`HapticFeedback.mediumImpact()`) on long-press selection triggers.
