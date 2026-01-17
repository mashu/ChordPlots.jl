# Color Schemes

ChordPlots uses modern, professional color palettes by default.

## Group-based Colors (Default)

Colors are assigned by group (column), using the Wong colorblind-friendly palette:

```julia
chordplot!(ax, cooc; colorscheme = :group)
```

## Categorical Colors

Each label gets a distinct color:

```julia
chordplot!(ax, cooc; colorscheme = :categorical)
```

```@raw html
<img src="assets/examples/categorical.png" alt="Categorical Colors" style="max-width: 600px;"/>
```

**What this shows:** This example uses `colorscheme=:categorical`, which assigns a distinct color to each individual label rather than grouping by category. Compare this to the basic example where all V labels share one color, all D labels another, etc. Here, every label (V1, V2, V3, D1, D2, J1, J2) gets its own unique color from the palette. This makes it easier to distinguish individual labels at a glance, but you lose the visual grouping by category. Ribbons blend the colors of their source and target labels, creating a gradient effect that shows which specific labels are connected.

## Custom Color Schemes

Create your own color scheme:

```julia
# Custom group colors
custom_cs = GroupColorScheme(
    Dict(
        :V_call => RGB(0.85, 0.32, 0.32),  # Red
        :D_call => RGB(0.32, 0.72, 0.32),  # Green
        :J_call => RGB(0.32, 0.45, 0.85)   # Blue
    ),
    RGB(0.6, 0.6, 0.6)  # Default color
)

chordplot!(ax, cooc; colorscheme = custom_cs)
```

## Color Utilities

```julia
# Modify colors
c = RGB(0.5, 0.5, 0.5)
c_alpha = with_alpha(c, 0.7)    # Add transparency
c_dark = darken(c, 0.2)         # Darken by 20%
c_light = lighten(c, 0.2)       # Lighten by 20%
```
