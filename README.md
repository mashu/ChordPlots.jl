# ChordPlots.jl
![chordplots_logo](https://github.com/user-attachments/assets/83f44cf6-e791-47e7-acbe-f36c8bfd1add)

A Julia package for creating beautiful chord diagrams with Makie. Visualize co-occurrence relationships between categorical variables.

## Quick Start

```julia
using CairoMakie, ChordPlots, DataFrames

# Create co-occurrence data
df = DataFrame(
    V = ["V1", "V1", "V2", "V2"],
    D = ["D1", "D2", "D1", "D2"],
    J = ["J1", "J1", "J2", "J2"]
)

cooc = cooccurrence_matrix(df, [:V, :D, :J])

# Plot
fig = Figure(size=(800, 800))
ax = Axis(fig[1,1])
chordplot!(ax, cooc)
setup_chord_axis!(ax)
fig
```

## Features

- **Simple API** - Create chord diagrams from DataFrames
- **Modern colors** - Professional color schemes (Wong palette, same as AlgebraOfGraphics)
- **Flexible filtering** - Filter by value, top N, or minimum flow
- **Customizable** - Control layout, colors, labels, and styling

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/yourusername/ChordPlots.jl")
```

## Usage

### Basic Plotting

```julia
chordplot!(ax, cooc;
    ribbon_alpha_by_value = true,  # Opacity scales with value
    min_arc_flow = 10,             # Filter small segments
    label_offset = 0.15,           # Adjust label position
    colorscheme = :group            # or :categorical
)
```

### Filtering

```julia
# Keep only top N labels
cooc_top = filter_top_n(cooc, 15)

# Filter by minimum value
cooc_filtered = filter_by_threshold(cooc, 5)
```

## Examples

See `examples/basic_usage.jl` for more examples.

## License

MIT License
