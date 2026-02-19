# Customization

Customize the appearance of your chord diagrams. Parameters are designed to work together: **`alpha`** controls opacity; **`alpha_by_value`** applies strength-based opacity; **focus** dimming affects labels, arcs, and ribbons automatically.

## Layout Parameters

Control the overall layout:

```julia
chordplot!(ax, cooc;
    inner_radius = 0.92,    # Inner radius for ribbons
    outer_radius = 1.0,     # Outer radius for arcs
    arc_width = 0.08,       # Width of arc segments
    gap_fraction = 0.03,    # Gap between arcs
    sort_by = :group,       # :group, :value, or :none
    arc_scale = 1.0,        # Fraction of width for arcs; < 1 adds gaps
    ribbon_width_power = 1.0 # Exponent for ribbon thickness
)
```

**Ribbon thickness** (`ribbon_width_power`): Ribbon widths are scaled as `(value/flow)^power`. Use a value greater than 1 (e.g. `1.5` or `2.0`) to make strong connections visibly thicker and weak ones thinner.

**Gaps between arcs** (`gap_fraction` and `arc_scale`): `gap_fraction` reserves that fraction of the circle for gaps. `arc_scale < 1` adds further separation.

## Ribbon Styling

```julia
chordplot!(ax, cooc;
    ribbon_tension = 0.5,   # Bezier curve tension (0 = straight, 1 = tight)
    min_ribbon_value = 0    # Hide ribbons below this value
)
```

## Opacity Control

Use **`alpha`** to control opacity. It accepts:

- **Single value**: applies to ribbons, arcs, and labels equally
- **Tuple `(ribbons, arcs, labels)`**: per-component control  
- **`ComponentAlpha`**: named fields for clarity

```julia
# All components at 70% opacity
chordplot!(ax, cooc; alpha = 0.7)

# Semi-transparent ribbons, solid arcs and labels (tuple)
chordplot!(ax, cooc; alpha = (0.5, 1.0, 1.0))

# Named fields for clarity (recommended)
chordplot!(ax, cooc; alpha = ComponentAlpha(ribbons=0.5, arcs=1.0, labels=1.0))
```

Default is `alpha = 1.0` (fully opaque).

## Strength-based Opacity

Use **`alpha_by_value`** to scale opacity by strength. It accepts:

- **`true`/`false`**: simple on/off with defaults
- **`ValueScaling`**: full control over which components scale

```julia
# Scale all components by value
chordplot!(ax, cooc; alpha_by_value = true)

# Full control with ValueScaling
chordplot!(ax, cooc; alpha_by_value = ValueScaling(
    enabled = true,
    components = (true, true, false),  # ribbons, arcs, but not labels
    min_alpha = 0.2,
    scale = :log
))
```

```@raw html
<img src="assets/examples/opacity.png" alt="Strength-based Opacity" style="max-width: 600px;"/>
```

### ValueScaling Fields

- `enabled::Bool`: Whether scaling is active
- `components::NTuple{3,Bool}`: Which components scale `(ribbons, arcs, labels)`
- `min_alpha::Float64`: Minimum opacity for weakest values (default: 0.1)
- `scale::Symbol`: `:linear` or `:log` scaling

Components set to `false` remain **fully opaque** (alpha = 1.0).

## Focus (Dim a Subset of Labels)

Set **`focus_group`** and **`focus_labels`** to highlight specific labels. Non-focused labels in that group are dimmed automatically.

```julia
chordplot!(ax, cooc; focus_group = :V_call, focus_labels = ["V1", "V2"])
```

## Arc Styling

```julia
chordplot!(ax, cooc;
    arc_width = 0.08,
    arc_strokewidth = 0.5,
    arc_strokecolor = :black
)
```

## Label Customization

```julia
chordplot!(ax, cooc;
    show_labels = true,
    label_offset = 0.12,        # Distance from arc
    label_fontsize = 10,
    label_color = :black,       # Use :group to color by category
    rotate_labels = true,       # Rotate to follow arc
    label_justify = :inside     # :inside or :outside
)
```

**Tips for long labels:**
- Increase `label_offset` (e.g., 0.18) to move labels further out
- Use `label_justify = :inside` to align toward circle center
- Adjust `label_fontsize` based on figure size
