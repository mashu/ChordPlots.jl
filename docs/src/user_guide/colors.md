# Color Schemes

Default palette is group-based (Wong-style, colorblind-oriented).

## Group colors (default)

```julia
chordplot!(ax, cooc; colorscheme = :group)
```

## Categorical (`:categorical`)

One color per label:

```julia
chordplot!(ax, cooc; colorscheme = :categorical)
```

**Gallery:** **[Categorical](../examples/gallery.md#Categorical-colors)**. Ribbons mix endpoint hues; you lose the single-hue-per-group cue from `:group`.

## Custom schemes

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
