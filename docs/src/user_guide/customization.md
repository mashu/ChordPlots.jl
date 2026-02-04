# Customization

Customize the appearance of your chord diagrams. Parameters are designed to work together: **`alpha`** multiplies all opacities; **`alpha_by_value`** applies strength-based opacity to ribbons, arcs, and labels; **focus** dimming affects labels, arcs, and ribbons automatically. No conflicting combinations.

## Layout Parameters

Control the overall layout:

```julia
chordplot!(ax, cooc;
    inner_radius = 0.92,    # Inner radius for ribbons
    outer_radius = 1.0,     # Outer radius for arcs
    arc_width = 0.08,       # Width of arc segments
    gap_fraction = 0.03,    # Gap between arcs
    sort_by = :group,       # :group, :value, or :none
    arc_scale = 1.0,        # Fraction of width for arcs; < 1 adds gaps between arcs
    ribbon_width_power = 1.0 # Exponent for ribbon thickness; > 1 makes thick vs thin more dramatic
)
```

**Ribbon thickness** (`ribbon_width_power`): Ribbon widths are scaled as `(value/flow)^power`. With `ribbon_width_power = 1.0` (default), widths are proportional to value. Use a value greater than 1 (e.g. `1.5` or `2.0`) to make strong connections visibly thicker and weak ones thinner, so the difference between thick and thin ribbons is more dramatic.

**Gaps between arcs** (`gap_fraction` and `arc_scale`): These work together and are not redundant. **`gap_fraction`** is the fraction of the full circle (2π) reserved for gaps between arcs (e.g. `0.03` → 3% gap, 97% arc content). **`arc_scale`** then scales only the arc (content) portion: with `arc_scale = 1.0` you keep that 97%; with `arc_scale < 1` (e.g. `0.7`) you use only 70% of the content for arcs and the rest becomes extra gap. So `gap_fraction` sets the baseline gap; `arc_scale < 1` adds further separation when needed.

## Ribbon Styling

Control ribbon appearance:

```julia
chordplot!(ax, cooc;
    ribbon_alpha = 0.65,
    ribbon_alpha_scale = :linear,      # :linear or :log (when alpha_by_value = true)
    ribbon_tension = 0.5,
    min_ribbon_value = 0
)
```

## Strength-based opacity (one switch for all)

Use **`alpha_by_value = true`** to scale opacity by strength for **ribbons, arcs, and labels** together: ribbons by co-occurrence value, arcs and labels by total flow of that label. Weaker connections and weaker nodes become dimmer; no extra options needed.

```julia
chordplot!(ax, cooc; alpha_by_value = true)
# Optional: log scale for better spread of small values
chordplot!(ax, cooc; alpha_by_value = true, ribbon_alpha_scale = :log)
```

```@raw html
<img src="assets/examples/opacity.png" alt="Strength-based Opacity" style="max-width: 600px;"/>
```

- Minimum opacity: 10% (never fully invisible)
- Ribbons: opacity by co-occurrence value (stronger link → more opaque)
- Arcs and labels: opacity by total flow of that label (stronger node → more opaque)

## Global opacity

Use **`alpha`** to fade the whole diagram: `alpha = 0.7` multiplies arc, ribbon, and label opacity by 0.7. Combines with strength-based opacity when `alpha_by_value = true`.

## Focus (dim a subset of labels)

Set **`focus_group`** (e.g. `:V_call`) and **`focus_labels`** (labels to keep highlighted). Non-focused labels in that group are dimmed automatically: their label, arc, and any ribbons touching them use `dim_color` and `dim_alpha`. No extra steps.

```julia
chordplot!(ax, cooc; focus_group = :V_call, focus_labels = ["V1", "V2"])
```

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
