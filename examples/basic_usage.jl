# examples/basic_usage.jl
# Example usage of ChordPlots.jl

using Pkg
Pkg.activate("..")

using ChordPlots
using DataFrames
using CairoMakie

#==============================================================================#
# Example 1: Basic VDJ Data
#==============================================================================#

println("Example 1: Basic VDJ chord diagram")

# Simulated VDJ gene segment data
vdj_data = DataFrame(
    V_call = [
        "IGHV1-2*01", "IGHV1-2*01", "IGHV1-2*01",
        "IGHV3-23*01", "IGHV3-23*01", "IGHV3-23*01", "IGHV3-23*01",
        "IGHV4-34*01", "IGHV4-34*01",
        "IGHV5-51*01", "IGHV5-51*01", "IGHV5-51*01"
    ],
    D_call = [
        "IGHD2-2*01", "IGHD3-10*01", "IGHD2-2*01",
        "IGHD2-2*01", "IGHD3-10*01", "IGHD1-1*01", "IGHD2-2*01",
        "IGHD1-1*01", "IGHD3-10*01",
        "IGHD2-2*01", "IGHD1-1*01", "IGHD3-10*01"
    ],
    J_call = [
        "IGHJ6*01", "IGHJ4*02", "IGHJ6*01",
        "IGHJ6*01", "IGHJ4*02", "IGHJ6*01", "IGHJ3*01",
        "IGHJ6*01", "IGHJ4*02",
        "IGHJ6*01", "IGHJ3*01", "IGHJ4*02"
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
    ribbon_alpha = 0.6,
    label_fontsize = 9,
    arc_width = 0.06
)

setup_chord_axis!(ax; padding=0.25)

save("example1_basic.png", fig)
println("  Saved: example1_basic.png")

#==============================================================================#
# Example 2: Custom Color Scheme
#==============================================================================#

println("\nExample 2: Custom colors")

# Define custom colors for each group
custom_colors = GroupColorScheme(
    Dict(
        :V_call => RGB(0.85, 0.32, 0.32),  # Red for V genes
        :D_call => RGB(0.32, 0.72, 0.32),  # Green for D genes  
        :J_call => RGB(0.32, 0.45, 0.85)   # Blue for J genes
    ),
    RGB(0.6, 0.6, 0.6)  # Default gray
)

fig2 = Figure(size=(800, 800))
ax2 = Axis(fig2[1,1], title="Custom Color Scheme")

chordplot!(ax2, cooc;
    colorscheme = custom_colors,
    ribbon_alpha = 0.65,
    ribbon_tension = 0.6,
    label_fontsize = 9
)

setup_chord_axis!(ax2)
save("example2_colors.png", fig2)
println("  Saved: example2_colors.png")

#==============================================================================#
# Example 3: Layout Configuration
#==============================================================================#

println("\nExample 3: Custom layout")

# Create custom layout configuration
config = LayoutConfig(
    inner_radius = 0.7,
    outer_radius = 0.95,
    gap_fraction = 0.08,
    start_angle = 0.0,  # Start from right
    direction = -1,     # Clockwise
    sort_by = :value    # Sort by total flow
)

layout = compute_layout(cooc, config)

fig3 = Figure(size=(800, 800))
ax3 = Axis(fig3[1,1], title="Custom Layout (sorted by value)")

chordplot!(ax3, cooc;
    inner_radius = config.inner_radius,
    outer_radius = config.outer_radius,
    gap_fraction = config.gap_fraction,
    sort_by = :value,
    arc_width = 0.1,
    ribbon_alpha = 0.55
)

setup_chord_axis!(ax3)
save("example3_layout.png", fig3)
println("  Saved: example3_layout.png")

#==============================================================================#
# Example 4: Filtered Data
#==============================================================================#

println("\nExample 4: Filtering")

# Create larger dataset
large_data = DataFrame(
    A = rand(["A1", "A2", "A3", "A4", "A5"], 100),
    B = rand(["B1", "B2", "B3", "B4"], 100),
    C = rand(["C1", "C2", "C3"], 100)
)

cooc_large = cooccurrence_matrix(large_data, [:A, :B, :C])

# Filter to top 8 labels
cooc_filtered = filter_top_n(cooc_large, 8)

fig4 = Figure(size=(800, 800))
ax4 = Axis(fig4[1,1], title="Filtered to Top 8 Labels")

chordplot!(ax4, cooc_filtered;
    ribbon_alpha = 0.5,
    min_ribbon_value = 5,  # Hide weak connections
    label_fontsize = 12
)

setup_chord_axis!(ax4)
save("example4_filtered.png", fig4)
println("  Saved: example4_filtered.png")

#==============================================================================#
# Example 5: Multi-panel Figure
#==============================================================================#

println("\nExample 5: Multi-panel comparison")

fig5 = Figure(size=(1200, 600))

# Panel A: By group
ax5a = Axis(fig5[1,1], title="Sorted by Group")
chordplot!(ax5a, cooc; sort_by=:group, ribbon_alpha=0.6)
setup_chord_axis!(ax5a)

# Panel B: By value
ax5b = Axis(fig5[1,2], title="Sorted by Value")
chordplot!(ax5b, cooc; sort_by=:value, ribbon_alpha=0.6)
setup_chord_axis!(ax5b)

# Add labels
Label(fig5[0, 1], "A", fontsize=20, font=:bold)
Label(fig5[0, 2], "B", fontsize=20, font=:bold)

save("example5_comparison.png", fig5)
println("  Saved: example5_comparison.png")

#==============================================================================#
# Example 6: Working with Layout Directly
#==============================================================================#

println("\nExample 6: Manual layout access")

layout = compute_layout(cooc)

println("  Number of arcs: ", narcs(layout))
println("  Number of ribbons: ", nribbons(layout))
println("  Arc details:")

for (i, arc) in enumerate(layout.arcs)
    label = cooc.labels[arc.label_idx]
    span_deg = rad2deg(arc_span(arc))
    println("    $label: $(round(span_deg, digits=1))°")
end

#==============================================================================#
# Example 7: Categorical Colors
#==============================================================================#

println("\nExample 7: Categorical color scheme")

fig7 = Figure(size=(800, 800))
ax7 = Axis(fig7[1,1], title="Categorical Colors (one per label)")

chordplot!(ax7, cooc;
    colorscheme = :categorical,
    ribbon_alpha = 0.55,
    label_fontsize = 9
)

setup_chord_axis!(ax7)
save("example7_categorical.png", fig7)
println("  Saved: example7_categorical.png")

#==============================================================================#
# Example 8: Styling Options
#==============================================================================#

println("\nExample 8: Various styling options")

fig8 = Figure(size=(800, 800), backgroundcolor=:gray95)
ax8 = Axis(fig8[1,1], 
           title="Styled Chord Diagram",
           backgroundcolor=:white)

chordplot!(ax8, cooc;
    ribbon_alpha = 0.7,
    ribbon_tension = 0.3,  # Less curved ribbons
    arc_width = 0.12,
    arc_strokewidth = 2,
    arc_strokecolor = :gray40,
    label_fontsize = 11,
    label_offset = 0.15,
    rotate_labels = true,
    label_color = :gray20
)

setup_chord_axis!(ax8; padding=0.35)
save("example8_styled.png", fig8)
println("  Saved: example8_styled.png")

println("\nAll examples completed!")
