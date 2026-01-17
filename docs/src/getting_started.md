# Getting Started

This guide will help you create your first chord diagram with ChordPlots.jl.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/mashu/ChordPlots.jl")
```

## Your First Chord Diagram

```julia
using CairoMakie, ChordPlots, DataFrames

# Create sample data
df = DataFrame(
    V = ["V1", "V1", "V2", "V2"],
    D = ["D1", "D2", "D1", "D2"],
    J = ["J1", "J1", "J2", "J2"]
)

# Create co-occurrence matrix
cooc = cooccurrence_matrix(df, [:V, :D, :J])

# Create plot
fig = Figure(size=(800, 800))
ax = Axis(fig[1,1], title="My First Chord Diagram")
chordplot!(ax, cooc)
setup_chord_axis!(ax)
fig
```

```@raw html
<img src="assets/examples/basic.png" alt="Basic Chord Diagram" style="max-width: 600px;"/>
```

**What you see:** This basic chord diagram shows the default visualization. Labels (V1, V2, V3, D1, D2, J1, J2) are arranged around the circle, grouped by their category. The colored arcs represent each label, and the curved ribbons connect labels that appear together in the data. Ribbon thickness indicates how frequently labels co-occur. Colors are assigned by group (all V labels share one color, all D labels another, etc.), using the default Wong color palette for a professional, colorblind-friendly appearance.

## What Happens Here?

1. **Data Preparation**: Each row in the DataFrame represents one observation with multiple categorical variables
2. **Co-occurrence Matrix**: `cooccurrence_matrix` counts how often labels from different groups appear together
3. **Plotting**: `chordplot!` creates the visual representation
4. **Setup**: `setup_chord_axis!` configures the axis for optimal display

## Next Steps

- Learn about [creating co-occurrence data](user_guide/creating_data.md)
- Explore [customization options](user_guide/customization.md)
- See [example visualizations](examples/basic.md)
