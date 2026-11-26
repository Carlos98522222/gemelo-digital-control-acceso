---
name: Tijuana Maquila Digital Twin & Access Control
colors:
  surface: '#0f1418'
  surface-dim: '#0f1418'
  surface-bright: '#353a3e'
  surface-container-lowest: '#0a0f13'
  surface-container-low: '#171c20'
  surface-container: '#1b2024'
  surface-container-high: '#262b2f'
  surface-container-highest: '#30353a'
  on-surface: '#dfe3e9'
  on-surface-variant: '#bcc9cd'
  inverse-surface: '#dfe3e9'
  inverse-on-surface: '#2c3135'
  outline: '#869397'
  outline-variant: '#3d494c'
  surface-tint: '#4cd7f6'
  primary: '#4cd7f6'
  on-primary: '#003640'
  primary-container: '#06b6d4'
  on-primary-container: '#00424f'
  inverse-primary: '#00687a'
  secondary: '#4edea3'
  on-secondary: '#003824'
  secondary-container: '#00a572'
  on-secondary-container: '#00311f'
  tertiary: '#d0bcff'
  on-tertiary: '#3c0091'
  tertiary-container: '#b395ff'
  on-tertiary-container: '#4900ae'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#acedff'
  primary-fixed-dim: '#4cd7f6'
  on-primary-fixed: '#001f26'
  on-primary-fixed-variant: '#004e5c'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#e9ddff'
  tertiary-fixed-dim: '#d0bcff'
  on-tertiary-fixed: '#23005c'
  on-tertiary-fixed-variant: '#5516be'
  background: '#0f1418'
  on-background: '#dfe3e9'
  surface-variant: '#30353a'
typography:
  headline-xl:
    fontFamily: Inter
    fontSize: 2rem
    fontWeight: '700'
    lineHeight: 2.5rem
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 1.5rem
    fontWeight: '600'
    lineHeight: 2rem
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Inter
    fontSize: 1.125rem
    fontWeight: '600'
    lineHeight: 1.5rem
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 1rem
    fontWeight: '400'
    lineHeight: 1.5rem
  body-md:
    fontFamily: Inter
    fontSize: 0.875rem
    fontWeight: '400'
    lineHeight: 1.25rem
  body-sm:
    fontFamily: Inter
    fontSize: 0.75rem
    fontWeight: '400'
    lineHeight: 1rem
  data-mono-lg:
    fontFamily: JetBrains Mono
    fontSize: 1.25rem
    fontWeight: '600'
    lineHeight: 1.5rem
    letterSpacing: 0.02em
  data-mono-md:
    fontFamily: JetBrains Mono
    fontSize: 0.875rem
    fontWeight: '500'
    lineHeight: 1.25rem
    letterSpacing: 0.01em
  data-mono-sm:
    fontFamily: JetBrains Mono
    fontSize: 0.75rem
    fontWeight: '500'
    lineHeight: 1rem
    letterSpacing: 0.03em
  badge-technical:
    fontFamily: JetBrains Mono
    fontSize: 0.6875rem
    fontWeight: '700'
    lineHeight: 0.875rem
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-lg: 1.5rem
  margin: 1.25rem
  margin-lg: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
  space-2xl: 2rem
---

## Brand & Style

This design system establishes a high-precision, mission-critical digital twin monitoring interface for maquiladora manufacturing facilities along the Tijuana industrial corridor. Tailored for plant security superintendents, physical asset protection teams, and OT/SCADA engineers, the interface prioritizes immediate cognitive decompression in 24/7 dark-room control environments. 

The aesthetic fuses **Tactical Operational Technology (OT)** with **Engineered Dark-Mode Minimalism**. It avoids consumer-grade gloss, neon bloat, and decorative distractions, focusing instead on instant status telemetry, exact spatial orientation across plant turnstiles and dock gates, and unambiguous access verdicts. The interface delivers absolute authority, structural clarity, and zero-latency operational confidence under active incident triage.

## Colors

The palette is engineered specifically for low-fatigue, continuous-observation displays in industrial monitoring hubs.

### Structural Foundations
- **Canvas Base (`#0F1418`)**: Deep graphite black for the root canvas, minimizing phosphor fatigue.
- **Surface Elevation 1 (`#171E24`)**: Dark steel slate for monitoring cards, telemetry panels, and plant floor layout backdrops.
- **Surface Elevation 2 / Sub-panels (`#1E293B`)**: Recessed modules, table headers, and tactical controls.
- **Subtle Structural Borders (`#26333D`)**: Primary hairline dividers separating monitoring quadrants.
- **Interactive / Focus Borders (`#334155`)**: Hover-state card frames, active panel boundaries, and structural segment dividers.

### Semantic & Telemetry Status Palette
Strict functional assignment governs all state colors; decorative uses are strictly forbidden:
- **Cyan (`#06B6D4`) — System Telemetry & Power**: Active sync loops, reader ping status, PLC heartbeat, edge gateway telemetry, and simulation runtime mode.
- **Emerald Green (`#10B981`) — Authorized / Permitted**: Valid badge scan, verified biometrics, unlocked turnstile, clear egress, emergency muster zone clear.
- **Crimson Red (`#EF4444`) — Breach / Denied / Critical**: Forged badge, tailgating detected, door forced open, offline controller, lockdown override, system fault.
- **Amber (`#F59E0B`) — Alert / Conditional Override**: Forced open warning, anti-passback violation pending review, uncalibrated optical sensor, door held ajar.
- **Amethyst Violet (`#8B5CF6`, Tint `#A78BFA`) — Indeterminate / Unknown**: Contact bounce, offline dry contact, unmapped relay, unread RFID frequency, pending sync.

### Text Contrast Tiers
- **Text High-Emphasis (`#F8FAFC`)**: Status outputs, card IDs, authorization verdicts.
- **Text Medium-Emphasis (`#94A3B8`)**: Zone identifiers, hardware descriptors, metadata labels.
- **Text Muted / Hardware Stamp (`#64748B`)**: Firmware numbers, MAC addresses, inactive ports.

## Typography

Typography functions as a precision instrument where sans-serif handles structural interface readability and monospaced typography handles streaming industrial telemetry.

- **System & Control Labeling (`Inter`)**: Used for all contextual headers, operator prompts, zone descriptions, and operational instructions. High x-height and clear apertures guarantee legibility on wall-mounted multi-screen arrays.
- **Hardware Telemetry & Timestamps (`JetBrains Mono`)**: Strict tabular alignment for timestamps (`YYYY-MM-DD HH:mm:ss.SSS`), badge hex codes (`UID: 0x4A8F90C2`), Wiegand wire codes, PLC relay bitmasks, and ping latencies. Numeric characters never shift column widths during real-time data cascades.

## Layout & Spacing

The layout is built upon an engineering-density **12-column fluid grid system** optimized for high-resolution desktop control consoles (1080p, 1440p, and multi-monitor setups) with responsive collapse patterns for portable operational tablets (field audits).

- **Screen Canvas Boundaries**: Standard horizontal padding is set at `margin` (`1.25rem` / `20px`) on standard consoles, expanding to `margin-lg` (`2rem` / `32px`) on wide monitoring stations.
- **Operational Grouping**: Sub-components inside sensor telemetry blocks use compact density tokens (`space-xs` and `space-sm`) to maximize spatial information density without clutter.
- **Section Separation**: Main structural segments (Twin Viewport, Live Access Feed, Controller Matrix) are isolated using `gutter-lg` (`1.5rem` / `24px`) with hairlines (`#26333D`).
- **Responsive Adaptations**: On tablet or collapsed modes, the 12-column twin/matrix view stacks into an incident-first layout: Live Alert Feed pins to the top, followed by 2D plant floor zoning, and hardware controller diagnostics at the base.

## Elevation & Depth

This design system deliberately excludes soft ambient drop-shadows and blurred neomorphism. In mission-critical environments, diffuse blurs degrade panel boundaries under variable ambient lighting. Depth is executed strictly through **Tonal Layering and Hairline Precision Outlines**:

- **Ground Plane (`#0F1418`)**: Root viewport level. Floor map SVG canvas, background telemetry grids, and architectural boundary markers rest here.
- **Card Containers (`#171E24`)**: Elevated by color value, encapsulated with a crisp 1px border (`#26333D`).
- **Tactile Modules & Controls (`#1E293B`)**: Command buttons, simulation scenario switchers, and input dropdowns sit inside cards with an enhanced border tone (`#334155`).
- **Active State Glows**: Dynamic status indication uses a tightly bounded 2px–4px zero-spread outer hairline glow locked to the state's exact token (e.g., `0 0 0 1px #10B981, 0 0 8px rgba(16, 185, 129, 0.25)` for verified access).
- **Incident Modal / Command Overrides**: Framed in high-contrast `#334155` with an opaque backing scrim (`rgba(15, 20, 24, 0.85)`), retaining sharp physical presence.

## Shapes

The design system standardizes on **Level 2 Roundedness** tailored specifically to heavy-duty industrial touchscreens and modern consoles:

- **Cards and Surface Containers**: Configured with `rounded-lg` (`1rem` / `16px`) corners. This softens the massive canvas density while holding architectural precision against the 1px `#26333D` border.
- **Interactive Controls & Micro-Panels**: Configured with default radius (`0.5rem` / `8px` to `0.75rem` / `12px`) for tactical button grips, input boxes, and dropdown menus.
- **Micro-Badges & Hardware Tags**: Use tight `rounded-sm` (`0.25rem` / `4px`) shaping to replicate stamped industrial identification plates (asset tags) found on physical turnstiles, readers, and NEMA enclosures.

## Components

### 1. Hardware Micro-Insignias & Status Badges
- Replicates stamped physical enclosure plates.
- Rendered in `badge-technical` typography with uppercase monospace tracking (`JetBrains Mono`, `0.6875rem`, weight `700`).
- Background sits at 15% opacity of semantic color; border sits at 50% opacity of semantic color.
- States:
  - `AUTORIZADO`: Emerald Green (`#10B981`) text, matching dot indicator, solid dark core.
  - `DENEGADO`: Crimson Red (`#EF4444`) with pulsing warning indicator.
  - `INDETERMINADO`: Amethyst Violet (`#8B5CF6`) for transient wiring or offline packet states.
  - `SINC / SYNC`: Cyan (`#06B6D4`) steady dot for active Wiegand/OSDP channel.

### 2. Buttons & Tactical Action Triggers
- **Primary Operational Action (Emergency Release / Grant)**: High-contrast emerald or slate solid fills with stark white text, flat tactical press animation (instant `scale(0.98)`, no bouncy easing curves).
- **Hazard Override Action (Lockdown / Alarm Ack)**: Crimson `#EF4444` solid or outlined with hatched danger borders.
- **Secondary Actions**: Background `#1E293B`, 1px border `#334155`, text `#F8FAFC`.

### 3. Simulation Scenario Selector (Digital Twin Test Rig)
- Segmented mechanical switch bar housed within `#1E293B`.
- Options: `EN VIVO (PROD)`, `FALLA DE RED`, `EVACUACIÓN / INCENDIO`, `CORTE DE ENERGÍA`.
- Active selection snaps instantly without sliding lag; active pill uses `#06B6D4` with contrasting dark text `#0F1418` to indicate non-production simulation override.

### 4. Zero-Latency Instant Toggle Switch
- Rectangular toggle chassis with rounded-sm slider thumb.
- Designed for immediate state transitions (Relay Lock/Unlock, Anti-Passback Disable).
- State transition occurs in under 80ms; track changes between `#26333D` (Off) and `#10B981` / `#06B6D4` (Active).

### 5. Access Event Stream & Ledger Lists
- Alternating dark micro-striping (`#171E24` and `#13191F`).
- Columns align strictly via monospaced fields: Timestamp (`JetBrains Mono`), Turnstile Zone ID, Employee Credential ID, Department, Decision Badge.
- Direct inline highlight flashes green or red across the row upon packet arrival.

### 6. Telemetry & Twin Cards
- Header carries asset name in `Inter` (`headline-sm`) accompanied by reader address in `JetBrains Mono` (`MAC: 00:1B:44:11:3A:B7 | RS-485 CH2`).
- Frame styled with `#26333D` border, elevating to `#334155` on hover.
- Upper right corner hosts live ping status and real-time state badge.

### 7. Form Fields & Terminal Inputs
- Input background `#0F1418`, interior border `#26333D`, focus ring `#06B6D4` (1px clean stroke, no diffused outer glow).
- Fixed-pitch monospaced font used for credential overrides, IP entries, and manual relay triggers.