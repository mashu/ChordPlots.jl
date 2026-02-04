# Generate example plots for documentation
# Note: This assumes ChordPlots is already available via Pkg.develop()
using ChordPlots
using CairoMakie
using DataFrames
using Random

# Set random seed for reproducibility
Random.seed!(42)

# Create output directory
output_dir = joinpath(@__DIR__, "src", "assets", "examples")
mkpath(output_dir)

# Ensure CairoMakie is set up for headless rendering
CairoMakie.activate!(type = "png")

# Example 1: Basic chord diagram
println("Generating basic example...")
df_basic = DataFrame(
    V = ["V1", "V1", "V2", "V2", "V3"],
    D = ["D1", "D2", "D1", "D2", "D1"],
    J = ["J1", "J1", "J2", "J2", "J1"]
)
cooc_basic = cooccurrence_matrix(df_basic, [:V, :D, :J])
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Basic Chord Diagram")
chordplot!(ax, cooc_basic)
setup_chord_axis!(ax)
save(joinpath(output_dir, "basic.png"), fig)

# Example 2: With filtering
println("Generating filtering example...")
df_large = DataFrame(
    A = rand(["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"], 50),
    B = rand(["B1", "B2", "B3", "B4", "B5"], 50),
    C = rand(["C1", "C2", "C3", "C4"], 50)
)
cooc_large = cooccurrence_matrix(df_large, [:A, :B, :C])
cooc_filtered = filter_top_n(cooc_large, 8)
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Filtered (Top 8)")
chordplot!(ax, cooc_filtered)
setup_chord_axis!(ax)
save(joinpath(output_dir, "filtered.png"), fig)

# Example 3: Strength-based opacity (ribbons, arcs, labels)
println("Generating opacity example...")
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Strength-based Opacity")
chordplot!(ax, cooc_basic; alpha_by_value=true, ribbon_alpha=0.7)
setup_chord_axis!(ax)
save(joinpath(output_dir, "opacity.png"), fig)

# Example 4: Categorical colors
println("Generating categorical colors example...")
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Categorical Colors")
chordplot!(ax, cooc_basic; colorscheme=:categorical)
setup_chord_axis!(ax)
save(joinpath(output_dir, "categorical.png"), fig)

# Example 5: Custom layout
println("Generating custom layout example...")
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Custom Layout")
chordplot!(ax, cooc_basic; sort_by=:value, inner_radius=0.85, gap_fraction=0.05)
setup_chord_axis!(ax)
save(joinpath(output_dir, "layout.png"), fig)

println("All examples generated!")
