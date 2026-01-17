# ChordPlots.jl

A Julia package for creating chord diagrams using the Makie ecosystem. Designed for visualizing co-occurrence relationships between categorical variables, such as gene segment usage in immunology.

## Features

- **Type-stable design** with parametric types for compile-time optimization
- **Makie integration** via recipes for seamless plotting
- **Multiple dispatch** for extensibility
- **Proper abstractions** for testable, maintainable components
- **Flexible color schemes** supporting group-based, categorical, and gradient coloring
- **Configurable layouts** with control over gaps, sorting, and radii

## Installation

```julia
using Pkg
Pkg.add(url="path/to/ChordPlots")
```

## Quick Start

```julia
using CairoMakie, ChordPlots, DataFrames

# Example: VDJ gene segment usage
df = DataFrame(
    V_call = ["IGHV1-2*01", "IGHV1-2*01", "IGHV3-23*01", "IGHV3-23*01", "IGHV4-34*01"],
    D_call = ["IGHD2-2*01", "IGHD3-10*01", "IGHD2-2*01", "IGHD3-10*01", "IGHD1-1*01"],
    J_call = ["IGHJ6*01", "IGHJ4*02", "IGHJ6*01", "IGHJ4*02", "IGHJ6*01"]
)

# Create co-occurrence matrix
cooc = cooccurrence_matrix(df, [:V_call, :D_call, :J_call])

# Plot
fig = Figure(size=(800, 800))
ax = Axis(fig[1,1])
chordplot!(ax, cooc)
setup_chord_axis!(ax)
fig
```

## Architecture

### Core Types

```
AbstractChordData
└── CoOccurrenceMatrix{T, S}   # Parametric co-occurrence storage

AbstractLayout
└── ChordLayout{T}             # Computed arc and ribbon positions

AbstractGeometry
├── ArcSegment{T}              # Arc on outer circle
└── Ribbon{T}                  # Connection between arcs

AbstractColorScheme
├── GroupColorScheme{C}        # Color by group
├── CategoricalColorScheme{C}  # Distinct color per label
└── GradientColorScheme        # Value-based gradient
```

### Module Structure

```
ChordPlots/
├── types.jl        # Core type definitions
├── cooccurrence.jl # DataFrame → CoOccurrenceMatrix
├── geometry.jl     # Arcs, Bezier curves, paths
├── layout.jl       # Layout computation algorithms
├── colors.jl       # Color scheme handling
└── recipe.jl       # Makie plotting recipe
```

## Detailed Usage

### Creating Co-occurrence Data

From a DataFrame:
```julia
cooc = cooccurrence_matrix(df, [:Col1, :Col2, :Col3])
```

From raw data:
```julia
matrix = [10 5 2; 5 8 3; 2 3 6]
labels = ["A", "B", "C"]
cooc = CoOccurrenceMatrix(
    matrix, labels,
    [:Group1, :Group2],  # Group names
    [2, 1]               # Group sizes
)
```

### Filtering Data

```julia
# Remove low-frequency connections
filtered = filter_by_threshold(cooc, 5)

# Keep only top N labels
top = filter_top_n(cooc, 10)

# Normalize to frequencies
norm = normalize(cooc)
```

### Layout Configuration

```julia
config = LayoutConfig(
    inner_radius = 0.75,   # Ribbon attachment radius
    outer_radius = 1.0,    # Arc outer radius
    gap_fraction = 0.05,   # Gap between arcs (fraction of circle)
    start_angle = π/2,     # Start at top
    direction = 1,         # Counterclockwise
    sort_by = :group       # :group, :value, or :none
)

layout = compute_layout(cooc, config)
```

### Plotting Options

```julia
chordplot(cooc;
    # Layout
    inner_radius = 0.8,
    outer_radius = 1.0,
    arc_width = 0.08,
    gap_fraction = 0.03,
    sort_by = :group,
    
    # Ribbons
    ribbon_alpha = 0.6,
    ribbon_tension = 0.5,
    min_ribbon_value = 0,
    
    # Labels
    show_labels = true,
    label_offset = 0.12,
    label_fontsize = 10,
    rotate_labels = true,
    
    # Colors
    colorscheme = :group,  # or :categorical, or custom scheme
    
    # Arc styling
    arc_strokewidth = 0.5,
    arc_strokecolor = :black
)
```

### Custom Color Schemes

```julia
# Group-based colors
cs = group_colors(cooc)

# Custom group colors
custom_cs = GroupColorScheme(
    Dict(:V_call => RGB(0.8, 0.2, 0.2),
         :D_call => RGB(0.2, 0.8, 0.2),
         :J_call => RGB(0.2, 0.2, 0.8)),
    RGB(0.5, 0.5, 0.5)  # default
)

chordplot(cooc; colorscheme=custom_cs)
```

### Working with Layouts Directly

For advanced customization, compute and modify layouts:

```julia
layout = compute_layout(cooc)

# Filter ribbons by value
layout = filter_ribbons(layout, 5)

# Or keep only top N
layout = filter_ribbons_top_n(layout, 20)

# Access components
for arc in layout.arcs
    println("Label $(arc.label_idx): $(arc.start_angle) to $(arc.end_angle)")
end

for ribbon in layout.ribbons
    println("Connection: $(ribbon.source.label_idx) → $(ribbon.target.label_idx)")
end
```

### Geometry Utilities

Generate paths for custom rendering:

```julia
# Arc as polygon (for filling)
poly = arc_polygon(0.8, 1.0, 0.0, π/4)

# Ribbon path with custom tension
src = RibbonEndpoint(1, 0.0, 0.2)
tgt = RibbonEndpoint(2, π, π+0.2)
ribbon = Ribbon(src, tgt, 10.0)
path = ribbon_path(ribbon, 0.8; tension=0.6)

# Label positions
lp = label_position(arc, 1.0, 0.1; rotate=true)
```

## Example: Immunology VDJ Analysis

```julia
using CairoMakie, ChordPlots, DataFrames, CSV

# Load repertoire data
df = CSV.read("repertoire.csv", DataFrame)

# Select relevant columns and filter
df_filtered = filter(row -> !ismissing(row.v_call) && 
                            !ismissing(row.d_call) && 
                            !ismissing(row.j_call), df)

# Simplify gene names (remove allele info)
df_filtered.v_gene = first.(split.(df_filtered.v_call, "*"))
df_filtered.d_gene = first.(split.(df_filtered.d_call, "*"))
df_filtered.j_gene = first.(split.(df_filtered.j_call, "*"))

# Create co-occurrence
cooc = cooccurrence_matrix(df_filtered, [:v_gene, :d_gene, :j_gene])

# Filter to top genes
cooc_top = filter_top_n(cooc, 15)

# Create publication-quality figure
fig = Figure(size=(1000, 1000), fontsize=14)
ax = Axis(fig[1,1], title="VDJ Gene Segment Co-occurrence")

chordplot!(ax, cooc_top;
    ribbon_alpha = 0.5,
    label_fontsize = 12,
    colorscheme = :group,
    min_ribbon_value = 10
)

setup_chord_axis!(ax; padding=0.3)
save("vdj_chord.png", fig, px_per_unit=2)
```

## Design Philosophy

### Type Stability

All core types use parametric typing:
```julia
struct CoOccurrenceMatrix{T<:Real, S<:AbstractString}
    matrix::Matrix{T}
    labels::Vector{S}
    # ...
end
```

This enables:
- Compile-time type inference
- Efficient generated code
- Flexible numeric precision (Int, Float64, etc.)

### Multiple Dispatch

Operations specialize on types:
```julia
resolve_arc_color(::GroupColorScheme, arc, cooc) = # group-based logic
resolve_arc_color(::CategoricalColorScheme, arc, cooc) = # per-label logic
```

### Separation of Concerns

1. **Data layer**: `CoOccurrenceMatrix` stores raw data
2. **Layout layer**: `ChordLayout` computes positions
3. **Rendering layer**: Makie recipe draws visuals

Each layer can be tested and extended independently.

## License

MIT License
