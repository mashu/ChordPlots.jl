# Getting Started

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/mashu/ChordPlots.jl")
```

## First diagram

```julia
using CairoMakie, ChordPlots

matrix = [0 3 1;
          3 0 2;
          1 2 0]

labels, groups = groups_from((:G => ["A", "B", "C"]))
cooc = CoOccurrenceMatrix(matrix, labels, groups)

set_theme!(merge(theme_light(), chord_theme()))

fig = Figure(size = (800, 800))
ax = Axis(fig[1, 1], title = "My First Chord Diagram")
chordplot!(
    ax,
    cooc;
    colorscheme = :categorical,
    inner_radius = 0.78,
    arc_width = 0.06,
    gap_fraction = 0.02,
)
setup_chord_axis!(ax)
fig
```

You get three arcs (**A**, **B**, **C**) and ribbons for nonzero pairs; width follows your matrix. Doc PNGs use other matrices; see the **[Gallery](examples/gallery.md)**.

## Next

- [Creating Data](user_guide/creating_data.md) · [Basic Plotting](user_guide/basic_plotting.md) · [Customization](user_guide/customization.md)
