# TCM Integration Specification for RTSSB Component

## 1. Goal
To integrate real-time technical stability metrics ($X_{security}$, Latency) into the 'The Shield of Assurance' Design System to provide users with transparent system health monitoring via the RTSSB component.

## 2. Core Indicators (TCM Metrics)
- **Security Level:** Maps $X_{security}$ status to color/icon set.
- **Latency Status:** Maps Latency results to a three-state indicator (Stable, Warning, Critical).
- **System Health:** Combined state determining the overall visual feedback.

## 3. Visual Mapping Rules
- **Color Palette:** Use Deep Teal ($\text{#008080}$) for Optimal states, Amber ($\text{#FFBF00}$) for Monitor states, and Red ($\text{#D93636}$) for Alert states.
- **Hierarchy:** Security Level is the primary status indicator; Latency Status acts as a secondary, real-time performance overlay.

## 4. RTSSB Component Layout Proposal
**Component Name:** ShieldStatusOverlay (RTSSB Component 내부에 삽입)

| Zone | Element | Data Source | Visual Treatment | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Top Bar** | Security Status Badge | $X_{security}$ | Icon + Color Coding | Overall Trust Level |
| **Middle Gauge** | Latency Health Indicator | Latency Status | Dynamic Gradient/Pulse Animation | Real-time Performance Feedback |
| **Bottom Detail** | History Log / Details | Latency History | Scrollable List | Detailed Troubleshooting Data |

## 5. Next Steps for Implementation (Designer)
1. Create Figma component variants for the ShieldStatusOverlay based on the three TCM states.
2. Finalize the token mapping for $X_{security}$ to the existing color palette.