# Basic Example

A simple example showing how to create a chord diagram.

```julia
using CairoMakie, ChordPlots, DataFrames

# Create sample data
df = DataFrame(
    V = ["V1", "V1", "V2", "V2", "V3"],
    D = ["D1", "D2", "D1", "D2", "D1"],
    J = ["J1", "J1", "J2", "J2", "J1"]
)

# Create co-occurrence matrix
cooc = cooccurrence_matrix(df, [:V, :D, :J])

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
