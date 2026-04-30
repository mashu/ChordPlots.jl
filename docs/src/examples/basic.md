# Basic Example

Minimal `chordplot!` for the V/D/J toy matrix used in the doc build. The **rendered figure** (shared doc theme, semi-transparent ribbons) is on the **[Gallery](gallery.md#Basic-chord-diagram)** only.

## Code

```julia
using CairoMakie, ChordPlots

matrix = [0 6 2 0 0 0;
          6 0 3 0 0 0;
          2 3 0 0 0 0;
          0 0 0 0 4 1;
          0 0 0 4 0 5;
          0 0 0 1 5 0]
labels = ["V1", "V2", "V3", "D1", "D2", "J1"]
groups = [
    GroupInfo{String}(:V, ["V1", "V2", "V3"], 1:3),
    GroupInfo{String}(:D, ["D1", "D2"], 4:5),
    GroupInfo{String}(:J, ["J1"], 6:6),
]
cooc = CoOccurrenceMatrix(matrix, labels, groups)

fig = Figure(size=(800, 800))
ax = Axis(fig[1,1], title="Basic Chord Diagram")
chordplot!(ax, cooc)
setup_chord_axis!(ax)
fig
```

To reproduce the **exact** PNG written by the docs, run **`docs/generate_examples.jl`** (Example 1); it sets explicit geometry and `merge(theme_light(), chord_theme())` like the rest of the gallery.
