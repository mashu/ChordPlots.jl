# Customization

Main knobs: **`alpha`**, **`alpha_by_value`** ([`ValueScaling`](@ref)), **`focus_*`** (dim other labels).

## Layout


```julia
chordplot!(ax, cooc;
    inner_radius = 0.88,    # Inner radius for ribbons (recipe default)
    outer_radius = 1.0,     # Outer radius for arcs
    arc_width = 0.06,       # Width of arc segments (recipe default)
    gap_fraction = 0.02,    # Gap between arcs (recipe default)
    sort_by = :group,       # :group, :value, or :none
    arc_scale = 1.0,        # Fraction of width for arcs; < 1 adds gaps
    ribbon_width_power = 1.0 # Exponent for ribbon thickness
)
```

Width scales as `(value/flow)^ribbon_width_power`; use `> 1` to stretch strong links. `gap_fraction` reserves circle fraction for gaps; `arc_scale < 1` adds extra gap between arc blocks. [`LayoutConfig`](@ref) defaults differ slightly from [`chordplot`](@ref); see docstrings.

## Ribbon geometry

```julia
chordplot!(ax, cooc;
    ribbon_tension = 0.5,   # Bezier curve tension (0 = straight, 1 = tight)
    min_ribbon_value = 0    # Hide ribbons below this value
)
```

## Co-occurrence layers (per donor)

For `CoOccurrenceLayers`, you can control how per-donor ribbons share arc space:

```julia
chordplot!(ax, cooc_layers;
    layers_pair_span = :stack_layers,   # :per_layer | :fixed_pairs | :stack_layers
    layers_stack_order = :given,        # :given | :value_desc | :value_asc (stacked only)
)
```

## Opacity (`alpha`)

Scalar (all components), tuple `(ribbons, arcs, labels)`, or [`ComponentAlpha`](@ref).

```julia
# All components at 70% opacity
chordplot!(ax, cooc; alpha = 0.7)

# Semi-transparent ribbons, solid arcs and labels (tuple)
chordplot!(ax, cooc; alpha = (0.5, 1.0, 1.0))

# Named fields for clarity (recommended)
chordplot!(ax, cooc; alpha = ComponentAlpha(ribbons=0.5, arcs=1.0, labels=1.0))
```

The recipe default is `ComponentAlpha(ribbons = 0.65, arcs = 0.95, labels = 1.0)`; pass `alpha` to override (see [`chordplot`](@ref)).

## Strength-based opacity (`alpha_by_value`)

`true` / `false`, or [`ValueScaling`](@ref) for per-component scaling.

```julia
# Scale all components by value
chordplot!(ax, cooc; alpha_by_value = true)

# Full control with ValueScaling
chordplot!(ax, cooc; alpha_by_value = ValueScaling(
    enabled = true,
    components = (ribbons = true, arcs = true, labels = false),
    min_alpha = 0.2,
    scale = :log
))
```

Rendered figure: **[Gallery — Strength-based opacity](../examples/gallery.md#Strength-based-opacity)**.

[`ValueScaling`](@ref): `enabled`, `components` as `(ribbons, arcs, labels)` or named tuple, `min_alpha`, `scale` (`:linear` / `:log`). Components left `false` stay fully opaque.

## Focus

Highlight a subset: **`focus_group`** + **`focus_labels`** (others in that group dim).

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

Long labels: raise `label_offset`, try `label_justify = :inside`, or reduce `label_fontsize`.
