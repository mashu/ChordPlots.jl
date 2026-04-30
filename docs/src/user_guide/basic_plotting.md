# Basic Plotting

## With an axis

```julia
fig = Figure(size=(800, 800))
ax = Axis(fig[1,1], title="My Chord Diagram")
chordplot!(ax, cooc)
setup_chord_axis!(ax)
fig
```

[`chordplot`](@ref) defaults to semi-transparent ribbons; adjust `alpha` / `alpha_by_value` if needed. Examples: **[Gallery](../examples/gallery.md)**.

## One-liner

```julia
fig, ax, plt = chordplot(cooc)
setup_chord_axis!(ax)
fig
```

## `setup_chord_axis!`

Call after every chord plot: square aspect, no decorations, sensible limits.

```julia
setup_chord_axis!(ax; padding=0.2)
```

Input data is always a [`CoOccurrenceMatrix`](@ref) or [`CoOccurrenceLayers`](@ref) you built upstream ([Creating Data](creating_data.md)).
