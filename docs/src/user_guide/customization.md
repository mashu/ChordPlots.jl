# Customization

Customize the appearance of your chord diagrams.

## Layout Parameters

Control the overall layout:

```julia
chordplot!(ax, cooc;
    inner_radius = 0.92,    # Inner radius for ribbons
    outer_radius = 1.0,     # Outer radius for arcs
    arc_width = 0.08,       # Width of arc segments
    gap_fraction = 0.03,    # Gap between arcs
    sort_by = :group        # :group, :value, or :none
)
```

## Ribbon Styling

Control ribbon appearance:

```julia
chordplot!(ax, cooc;
    ribbon_alpha = 0.65,              # Transparency
    ribbon_alpha_by_value = true,     # Scale opacity by value
    ribbon_alpha_scale = :linear,      # :linear or :log
    ribbon_tension = 0.5,              # Bezier curve tension
    min_ribbon_value = 0               # Hide ribbons below this value
)
```

```@raw html
<img src="assets/examples/opacity.png" alt="Value-based Opacity" style="max-width: 600px;"/>
```

**What this shows:** This example uses `ribbon_alpha_by_value=true` to make ribbon opacity vary based on co-occurrence value. Compare this to the basic example: here, thicker ribbons (higher co-occurrence counts) appear more opaque and prominent, while thinner ribbons (lower counts) are more transparent. This creates a visual hierarchy where the most important connections stand out clearly, while weaker connections fade into the background. The effect is subtle but effective - it helps guide the eye to the strongest relationships in your data.

**Value-based opacity** makes larger connections more visible:
- Minimum opacity: 10% (never fully invisible)
- Maximum opacity: `ribbon_alpha`
- Use `:log` scale for better distribution with small integer values

## Arc Styling

Customize arc segments:

```julia
chordplot!(ax, cooc;
    arc_width = 0.08,
    arc_alpha = 0.9,
    arc_strokewidth = 0.5,
    arc_strokecolor = :black
)
```

## Label Customization

Control labels:

```julia
chordplot!(ax, cooc;
    show_labels = true,
    label_offset = 0.12,        # Distance from arc
    label_fontsize = 10,
    label_color = :black,
    rotate_labels = true,        # Rotate to follow arc
    label_justify = :inside     # :inside or :outside
)
```

**Tips for long labels:**
- Increase `label_offset` (e.g., 0.18) to move labels further out
- Use `label_justify = :inside` to align toward circle center
- Adjust `label_fontsize` based on figure size
