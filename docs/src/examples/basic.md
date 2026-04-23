# Basic Example

A simple example showing how to create a chord diagram.

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

# Create plot
fig = Figure(size=(800, 800))
ax = Axis(fig[1,1], title="Basic Chord Diagram")
chordplot!(ax, cooc)
setup_chord_axis!(ax)
fig
```

```@raw html
<img src="assets/examples/basic.png" alt="Basic Example" style="max-width: 600px;"/>
```

**What this shows:** This is the default chord diagram with standard settings. Labels are arranged around the circle grouped by their category (V, D, J), and ribbons connect labels that co-occur. Ribbon thickness represents the co-occurrence frequency. Colors are assigned by group (each category gets a distinct color), and all ribbons use uniform opacity. This is the simplest way to visualize co-occurrence relationships.
