# examples/basic_usage.jl
# Example usage of ChordPlots.jl

using Pkg
Pkg.activate("..")

using ChordPlots
using DataFrames
using CairoMakie

# Simulated VDJ gene segment data
vdj_data = DataFrame(
    V_call = [
        "IGHV1-2*01", "IGHV1-2*01", "IGHV1-2*01",
        "IGHV3-23*01", "IGHV3-23*01", "IGHV3-23*01", "IGHV3-23*01",
        "IGHV4-34*01", "IGHV4-34*01",
        "IGHV5-51*01", "IGHV5-51*01", "IGHV5-51*01",
        "IGHV6-61*01", "IGHV6-61*01", "IGHV6-61*01"
    ],
    D_call = [
        "IGHD2-2*01", "IGHD3-10*01", "IGHD2-2*01",
        "IGHD2-2*01", "IGHD3-10*01", "IGHD1-1*01", "IGHD2-2*01",
        "IGHD1-1*01", "IGHD3-10*01",
        "IGHD2-2*01", "IGHD1-1*01", "IGHD3-10*01",
        "IGHD2-2*01", "IGHD3-10*01", "IGHD1-1*01"
    ],
    J_call = [
        "IGHJ6*01", "IGHJ4*02", "IGHJ6*01",
        "IGHJ6*01", "IGHJ4*02", "IGHJ6*01", "IGHJ3*01",
        "IGHJ6*01", "IGHJ4*02",
        "IGHJ6*01", "IGHJ3*01", "IGHJ4*02",
        "IGHJ6*01", "IGHJ4*02", "IGHJ6*01"
    ]
)

# Create co-occurrence matrix
cooc = cooccurrence_matrix(vdj_data, [:V_call, :D_call, :J_call])

println("  Labels: ", nlabels(cooc))
println("  Groups: ", ngroups(cooc))

# Create figure
fig = Figure(size=(800, 800))
ax = Axis(fig[1,1], title="VDJ Gene Segment Co-occurrence")

chordplot!(ax, cooc;
    label_fontsize = 9,
    arc_width = 0.06,
    alpha = 0.6
)

setup_chord_axis!(ax; padding=0.25)

save("example1_basic.png", fig)
println("  Saved: example1_basic.png")
