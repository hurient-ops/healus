---
name: Serene Medical
colors:
  surface: '#f8fafa'
  surface-dim: '#d8dada'
  surface-bright: '#f8fafa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f4'
  surface-container: '#eceeee'
  surface-container-high: '#e6e8e9'
  surface-container-highest: '#e1e3e3'
  on-surface: '#191c1d'
  on-surface-variant: '#3f4849'
  inverse-surface: '#2e3131'
  inverse-on-surface: '#eff1f1'
  outline: '#6f7979'
  outline-variant: '#bfc8c8'
  surface-tint: '#22686b'
  primary: '#1f6568'
  on-primary: '#ffffff'
  primary-container: '#3c7e81'
  on-primary-container: '#f3ffff'
  inverse-primary: '#90d2d5'
  secondary: '#ab2c5d'
  on-secondary: '#ffffff'
  secondary-container: '#fd6c9c'
  on-secondary-container: '#6e0034'
  tertiary: '#4f5f5f'
  on-tertiary: '#ffffff'
  tertiary-container: '#677877'
  on-tertiary-container: '#f3fffe'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#aceef1'
  primary-fixed-dim: '#90d2d5'
  on-primary-fixed: '#002021'
  on-primary-fixed-variant: '#004f52'
  secondary-fixed: '#ffd9e1'
  secondary-fixed-dim: '#ffb1c5'
  on-secondary-fixed: '#3f001b'
  on-secondary-fixed-variant: '#8b0e45'
  tertiary-fixed: '#d4e6e5'
  tertiary-fixed-dim: '#b8cac9'
  on-tertiary-fixed: '#0e1e1e'
  on-tertiary-fixed-variant: '#3a4a49'
  background: '#f8fafa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e3'
typography:
  display-lg:
    fontFamily: Noto Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Noto Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Noto Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Noto Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-sm:
    fontFamily: Noto Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.03em
  data-lg:
    fontFamily: Noto Sans
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 48px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 40px
  margin-mobile: 16px
  gutter: 16px
---

## Brand & Style

The design system is anchored in the concept of "Confident Serenity." For users managing insulin—a high-stakes, 24/7 task—the UI must act as a calming agent rather than a source of stress. The aesthetic balances **Modern Corporate** reliability with **Minimalist** clarity to ensure critical medical data is never obscured by decorative elements.

The target audience ranges from tech-savvy young adults to elderly patients, requiring a high degree of accessibility and cognitive ease. The visual language uses soft transitions, generous white space, and a structured hierarchy to evoke a sense of professional-grade safety and effortless control.

## Colors

This design system utilizes a "Clinical Chic" palette. The **Primary Teal (#509194)** is the foundation, used for active states and primary actions to promote a sense of biological harmony. The **Secondary Coral (#F06292)** is reserved strictly for high-priority alerts and "Stop" actions to prevent color fatigue and ensure instant recognition during emergencies.

The background uses a slightly tinted neutral (#F8FAFA) rather than pure white to reduce screen glare during nighttime use. A soft tertiary mint (#E0F2F1) is used for large surface areas like cards or progress bars to maintain a low-stress visual environment.

## Typography

The typography system prioritizes uncompromising legibility under duress. **Noto Sans** is utilized as the singular font family across all levels to provide a unified, cohesive experience. Chosen for its global accessibility standards and exceptional clarity across diverse digital displays, it ensures that both high-impact data and functional body text remain perfectly legible.

A specialized "data-lg" style is included for primary glucose readings, ensuring the most vital information is legible from a distance or with a quick glance. By standardizing on Noto Sans, the UI reduces cognitive load, offering a clean and professional aesthetic that feels both modern and medically reliable. All labels use a slightly increased letter spacing to maximize readability for users with visual impairments.

## Layout & Spacing

The design system employs a **Fluid Grid** model with a base-8 rhythm. This ensures consistency across various mobile device dimensions. Margins are set to a comfortable 16px on mobile to maximize screen real estate while preventing accidental "fat-finger" taps near the bezel.

Information density is kept low. Large "safe areas" are placed around interactive elements to accommodate users who may be experiencing tremors or reduced motor control during hypoglycemic episodes.

## Elevation & Depth

This design system uses **Ambient Shadows** to create a soft, tactile hierarchy. Shadows are never pure black; they are tinted with the primary teal at very low opacity (5-8%) to feel integrated with the UI.

Depth is used to signify "Press-ability":
- **Level 0 (Flat):** Background and secondary information.
- **Level 1 (Subtle Shadow):** Standard cards and informational containers.
- **Level 2 (Diffused Shadow):** Interactive buttons and active input fields.
- **Level 3 (High Blur):** Modals, emergency stop overlays, and critical alerts.

Low-contrast outlines (1px solid #E0E7E7) are used alongside shadows to define boundaries without adding visual noise.

## Shapes

The shape language is "Approachable Geometric." A **Rounded** setting (0.5rem base) is applied to all primary components to move away from the "harshness" of traditional medical equipment. Large containers, such as the main glucose graph card, utilize `rounded-xl` (1.5rem) to feel like a modern consumer lifestyle product.

Buttons and chips use a higher degree of rounding (fully pill-shaped) to distinguish them clearly from informational cards and data displays.

## Components

### Buttons & Chips
- **Primary Action:** Solid teal background, white text, pill-shaped. No gradients.
- **Emergency Stop:** Solid coral background with a subtle pulse animation for visibility.
- **Chips:** Used for "Time in Range" filters; they use a light teal tint when active and a simple outline when inactive.

### Input Fields & Controls
- **Inputs:** Soft-grey background with a 1px teal border that grows to 2px on focus.
- **Checkboxes:** Rounded squares with a teal fill and a clean white "check" icon.
- **Sliders:** Used for insulin dosage adjustments; the "thumb" of the slider is oversized (24px diameter) for easy manipulation.

### Cards
- **Data Cards:** Content is grouped into Level 1 elevation cards. Headings within cards are always "label-sm" for categorical clarity.

### Iconography
- **Style:** 1.5pt stroke weight, "thin-line" icons with slightly rounded caps and joins. 
- **Navigation:** Icons remain hollow when inactive and fill with the primary teal color when active.

### Specialized Components
- **Trend Indicators:** Simple 45-degree or 90-degree arrows indicating glucose velocity.
- **Status Rings:** A circular progress indicator around the primary glucose value to show "Insulin On Board" (IOB) or "Carbs On Board" (COB).