```@raw html
<div class="cp-hero">
  <img src="https://github.com/user-attachments/assets/83f44cf6-e791-47e7-acbe-f36c8bfd1add" width="120" height="120" alt="ChordPlots" />
  <h1>ChordPlots.jl</h1>
  <p class="cp-lead">Chord diagrams in Makie from matrices you supply: <code>CoOccurrenceMatrix</code> for a single table, or <code>CoOccurrenceLayers</code> when each donor or batch has its own layer. Group and categorical colors, filtering, and layouts that work in papers.</p>
  <div class="cp-hero-actions">
    <a class="cp-btn cp-btn-primary" href="examples/gallery.html">Gallery</a>
    <a class="cp-btn cp-btn-ghost" href="getting_started.html">Getting started</a>
  </div>
</div>
```

You supply a weight matrix (or [`CoOccurrenceLayers`](@ref)); ChordPlots maps it to layout and color and does not normalize for you.

## Quick Start

```julia
using CairoMakie, ChordPlots

matrix = [0 3 1;
          3 0 2;
          1 2 0]
labels, groups = groups_from((:G => ["A", "B", "C"]))
cooc = CoOccurrenceMatrix(matrix, labels, groups)

set_theme!(merge(theme_light(), chord_theme()))

fig = Figure(size = (800, 800))
ax = Axis(fig[1, 1])
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

Default ribbons are slightly transparent; tune with `alpha` / `alpha_by_value` ([`chordplot`](@ref)).

**Next:** [Gallery](examples/gallery.md) · [Getting Started](getting_started.md) · [User Guide](user_guide/creating_data.md) · [API](api.md)

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/mashu/ChordPlots.jl")
```

## License

MIT License
