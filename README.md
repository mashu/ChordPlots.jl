# ChordPlots.jl

![chordplots_logo](https://github.com/user-attachments/assets/83f44cf6-e791-47e7-acbe-f36c8bfd1add)

[![CI](https://github.com/mashu/ChordPlots.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/mashu/ChordPlots.jl/actions/workflows/CI.yml)
[![Codecov](https://codecov.io/gh/mashu/ChordPlots.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/mashu/ChordPlots.jl)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://mashu.github.io/ChordPlots.jl/stable)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://mashu.github.io/ChordPlots.jl/dev)

A Julia package for creating beautiful chord diagrams with Makie. Visualize co-occurrence relationships between categorical variables.

## Quick Start

```julia
using CairoMakie, ChordPlots

matrix = [0 3 1;
          3 0 2;
          1 2 0]
labels = ["A", "B", "C"]
groups = [GroupInfo{String}(:G, labels, 1:3)]
cooc = CoOccurrenceMatrix(matrix, labels, groups)

fig = Figure(size=(800, 800))
ax = Axis(fig[1,1])
chordplot!(ax, cooc)
setup_chord_axis!(ax)
fig
```

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/mashu/ChordPlots.jl")
```

## Documentation

📚 **[Full Documentation](https://mashu.github.io/ChordPlots.jl/stable)** - Complete guide with examples, features, and API reference.

## License

MIT License
