# src/colors.jl
# Color utilities for chord diagrams

using Colors

#==============================================================================#
# Color Scheme Types
#==============================================================================#

"""
    AbstractColorScheme

Abstract type for color schemes used in chord diagrams.
"""
abstract type AbstractColorScheme end

"""
    GroupColorScheme{C<:Colorant}

Assigns colors based on label groups.

# Fields
- `group_colors::Dict{Symbol, C}`: Color for each group
- `default_color::C`: Fallback color
"""
struct GroupColorScheme{C<:Colorant} <: AbstractColorScheme
    group_colors::Dict{Symbol, C}
    default_color::C
end

"""
    CategoricalColorScheme{C<:Colorant}

Assigns distinct colors to each label.

# Fields
- `colors::Vector{C}`: Color palette
"""
struct CategoricalColorScheme{C<:Colorant} <: AbstractColorScheme
    colors::Vector{C}
end

"""
    GradientColorScheme

Colors based on a gradient (e.g., by value).

# Fields
- `colormap::Symbol`: Makie colormap name
- `range::Tuple{Float64, Float64}`: Value range for mapping
"""
struct GradientColorScheme <: AbstractColorScheme
    colormap::Symbol
    range::Tuple{Float64, Float64}
end

"""
    DivergingColorScheme{C<:Colorant}

Color scheme for signed values (e.g., differences) using a diverging colormap.
Maps negative values to one color, zero to neutral, positive to another color.

# Fields
- `negative_color::C`: Color for most negative values
- `neutral_color::C`: Color for zero/neutral values
- `positive_color::C`: Color for most positive values
- `range::Tuple{Float64, Float64}`: (min, max) value range for normalization
- `symmetric::Bool`: If true, range is symmetric around zero (max absolute value)
"""
struct DivergingColorScheme{C<:Colorant} <: AbstractColorScheme
    negative_color::C
    neutral_color::C
    positive_color::C
    range::Tuple{Float64, Float64}
    symmetric::Bool
end

#==============================================================================#
# Color Palettes
#==============================================================================#

"""
    wong_palette() -> Vector{RGB{Float64}}

Returns Wong's colorblind-friendly palette (same as Makie/AoG default).
These are eye-catching but not garish, professional colors.
"""
function wong_palette()::Vector{RGB{Float64}}
    # Wong's colorblind-friendly palette (same as Makie/AoG uses)
    # From: Wong, B. (2011). Points of view: Color blindness. Nature Methods, 8(6), 441.
    [
        RGB(0.0, 0.4470588235294118, 0.6980392156862745),    # Blue
        RGB(0.0, 0.6196078431372549, 0.45098039215686275),    # Green
        RGB(0.8352941176470589, 0.3686274509803922, 0.0),     # Orange
        RGB(0.8, 0.47450980392156861, 0.6549019607843137),     # Pink
        RGB(0.9411764705882353, 0.8941176470588236, 0.25882352941176473), # Yellow
        RGB(0.33725490196078434, 0.7058823529411765, 0.9137254901960784), # Sky Blue
        RGB(0.0, 0.6196078431372549, 0.45098039215686275),    # Bluish Green
        RGB(0.9019607843137255, 0.6235294117647059, 0.0),     # Vermillion
    ]
end

"""
    modern_palette() -> Vector{RGB{Float64}}

Returns a curated modern, professional color palette.
Colors are chosen for visual appeal, professionalism, and good contrast.
"""
function modern_palette()::Vector{RGB{Float64}}
    # Modern, professional palette inspired by contemporary design systems
    # Colors are vibrant but not garish, professional and pleasant
    # Optimized for data visualization with good contrast and accessibility
    [
        RGB(0.25882352941176473, 0.5725490196078431, 0.7764705882352941),   # Modern Blue
        RGB(0.9568627450980393, 0.42745098039215684, 0.2627450980392157),   # Coral/Orange
        RGB(0.19607843137254902, 0.7137254901960784, 0.4823529411764706),   # Teal/Green
        RGB(0.5490196078431373, 0.33725490196078434, 0.29411764705882354),   # Warm Brown
        RGB(0.7803921568627451, 0.47450980392156861, 0.7764705882352941),   # Soft Purple
        RGB(0.9450980392156862, 0.7686274509803922, 0.058823529411764705),  # Golden Yellow
        RGB(0.12156862745098039, 0.4666666666666667, 0.7058823529411765),   # Deep Blue
        RGB(0.8392156862745098, 0.3764705882352941, 0.0),                   # Burnt Orange
        RGB(0.17254901960784313, 0.6274509803921569, 0.17254901960784313), # Forest Green
        RGB(0.5803921568627451, 0.403921568627451, 0.7411764705882353),    # Rich Purple
        RGB(0.8901960784313725, 0.10196078431372549, 0.10980392156862745), # Modern Red
        RGB(0.0, 0.6196078431372549, 0.45098039215686275),                  # Emerald
        RGB(0.7372549019607844, 0.7411764705882353, 0.13333333333333333),  # Olive
        RGB(0.09019607843137255, 0.7450980392156863, 0.8117647058823529),  # Cyan
        RGB(0.6196078431372549, 0.8549019607843137, 0.8980392156862745),   # Sky Blue
        RGB(0.9921568627450981, 0.6823529411764706, 0.3803921568627451),    # Peach
        RGB(0.6980392156862745, 0.6705882352941176, 0.8235294117647058),   # Lavender
        RGB(0.8627450980392157, 0.2980392156862745, 0.22745098039215686),  # Rust Red
        RGB(0.3411764705882353, 0.34901960784313724, 0.3803921568627451),   # Charcoal
        RGB(0.5294117647058824, 0.807843137254902, 0.9215686274509803),    # Light Cyan
    ]
end

"""
    get_colors_for_count(n::Int) -> Vector{RGB{Float64}}

Returns n colors from the modern palette, cycling if needed.
"""
function get_colors_for_count(n::Int)::Vector{RGB{Float64}}
    palette = modern_palette()
    if n <= length(palette)
        return palette[1:n]
    else
        # Cycle through palette if we need more colors
        result = RGB{Float64}[]
        for i in 1:n
            push!(result, palette[mod1(i, length(palette))])
        end
        return result
    end
end

#==============================================================================#
# Color Scheme Construction
#==============================================================================#

"""
    group_colors(cooc::AbstractChordData; palette=:default)

Create a color scheme based on groups using Makie's default categorical palette
(same as AlgebraOfGraphics uses - Wong colors, colorblind-friendly).

# Arguments
- `palette::Symbol`: Color palette style (`:default` for Makie/AoG palette, `:modern` for custom)
"""
function group_colors(cooc::AbstractChordData; palette::Symbol = :default)
    n_groups = ngroups(cooc)
    
    if palette == :default
        # Use Wong's colorblind-friendly palette (same as Makie/AoG default)
        # This gives us eye-catching but not garish, professional colors
        wong = wong_palette()
        colors = wong[1:min(n_groups, length(wong))]
        # If we need more colors, cycle through the palette
        if n_groups > length(colors)
            for i in (length(colors)+1):n_groups
                push!(colors, wong[mod1(i, length(wong))])
            end
        end
    else
        # Fallback to modern palette
        colors = get_colors_for_count(n_groups)
    end
    
    group_color_dict = Dict{Symbol, RGB{Float64}}()
    for (i, group) in enumerate(cooc.groups)
        # Convert to RGB if needed
        c = colors[i]
        if c isa RGB
            group_color_dict[group.name] = c
        else
            group_color_dict[group.name] = RGB(c)
        end
    end
    
    # Modern neutral gray for defaults
    GroupColorScheme(group_color_dict, RGB(0.4, 0.4, 0.4))
end

"""
    categorical_colors(n::Int; palette=:default)

Create n distinguishable colors using Makie's default categorical palette
(same as AlgebraOfGraphics uses - Wong colors, colorblind-friendly).

# Arguments
- `palette::Symbol`: Color palette style (`:default` for Makie/AoG palette, `:modern` for custom)
"""
function categorical_colors(n::Int; palette::Symbol = :default)
    if palette == :default
        # Use Wong's colorblind-friendly palette (same as Makie/AoG default)
        wong = wong_palette()
        colors = wong[1:min(n, length(wong))]
        # If we need more colors, cycle through the palette
        if n > length(colors)
            for i in (length(colors)+1):n
                push!(colors, wong[mod1(i, length(wong))])
            end
        end
        CategoricalColorScheme(colors)
    else
        colors = get_colors_for_count(n)
        CategoricalColorScheme(colors)
    end
end

"""
    gradient_colors(; colormap=:viridis, min_val=0.0, max_val=1.0)

Create a gradient-based color scheme.
"""
function gradient_colors(; 
    colormap::Symbol = :viridis, 
    min_val::Float64 = 0.0, 
    max_val::Float64 = 1.0
)
    GradientColorScheme(colormap, (min_val, max_val))
end

"""
    diverging_colors(cooc::AbstractChordData; negative=:steelblue, neutral=:white, positive=:firebrick, symmetric=true)

Create a diverging color scheme for signed values (e.g., from `diff()`).

Ribbons are colored by their value: negative → neutral → positive.
Use with `diff(a, b; absolute=false)` to visualize increases vs decreases.

# Arguments
- `cooc`: The chord data (used to determine value range)
- `negative`: Color for most negative values (default: steel blue)
- `neutral`: Color for zero (default: white)
- `positive`: Color for most positive values (default: firebrick red)
- `symmetric`: If true (default), range is symmetric around zero

# Example
```julia
d = diff(cooc_after, cooc_before; absolute=false)  # positive = increase
fig, ax, plt = chordplot(d; colorscheme=diverging_colors(d))
```
"""
function diverging_colors(
    cooc::AbstractChordData;
    negative::Union{Colorant, Symbol} = RGB(0.27, 0.51, 0.71),  # steelblue
    neutral::Union{Colorant, Symbol} = RGB(0.97, 0.97, 0.97),   # near-white
    positive::Union{Colorant, Symbol} = RGB(0.70, 0.13, 0.13),  # firebrick
    symmetric::Bool = true
)
    # Convert symbols to colors if needed
    neg_c = negative isa Symbol ? parse(Colorant, string(negative)) : negative
    neu_c = neutral isa Symbol ? parse(Colorant, string(neutral)) : neutral
    pos_c = positive isa Symbol ? parse(Colorant, string(positive)) : positive
    
    # Get value range from matrix
    n = nlabels(cooc)
    vals = Float64[]
    for j in 2:n
        for i in 1:(j-1)
            push!(vals, Float64(cooc.matrix[i, j]))
        end
    end
    
    if isempty(vals)
        min_val, max_val = -1.0, 1.0
    else
        min_val = minimum(vals)
        max_val = maximum(vals)
    end
    
    # Symmetric: use max absolute value for both ends
    if symmetric
        abs_max = max(abs(min_val), abs(max_val))
        min_val = -abs_max
        max_val = abs_max
    end
    
    # Ensure range is not zero
    if min_val ≈ max_val
        min_val = min_val - 1.0
        max_val = max_val + 1.0
    end
    
    DivergingColorScheme(RGB(neg_c), RGB(neu_c), RGB(pos_c), (min_val, max_val), symmetric)
end

"""
    diff_colors(cooc::AbstractChordData; kwargs...)

Alias for `diverging_colors` - creates a color scheme for difference matrices.

# Example
```julia
d = diff(cooc_after, cooc_before; absolute=false)
chordplot(d; colorscheme=diff_colors(d))
```
"""
diff_colors(cooc::AbstractChordData; kwargs...) = diverging_colors(cooc; kwargs...)

#==============================================================================#
# Color Resolution
#==============================================================================#

"""
    resolve_arc_color(scheme::AbstractColorScheme, arc::ArcSegment, cooc::AbstractChordData)

Get the color for an arc based on the color scheme.
"""
function resolve_arc_color(
    scheme::GroupColorScheme,
    arc::ArcSegment,
    cooc::AbstractChordData
)
    group = get_group(cooc, arc.label_idx)
    get(scheme.group_colors, group, scheme.default_color)
end

function resolve_arc_color(
    scheme::CategoricalColorScheme,
    arc::ArcSegment,
    cooc::AbstractChordData
)
    idx = mod1(arc.label_idx, length(scheme.colors))
    scheme.colors[idx]
end

"""
    resolve_ribbon_color(scheme::AbstractColorScheme, ribbon::Ribbon, cooc::AbstractChordData; blend=true)

Get the color for a ribbon. By default blends source and target colors.
"""
function resolve_ribbon_color(
    scheme::GroupColorScheme,
    ribbon::Ribbon,
    cooc::AbstractChordData;
    blend::Bool = true
)
    src_group = get_group(cooc, ribbon.source.label_idx)
    tgt_group = get_group(cooc, ribbon.target.label_idx)
    
    src_color = get(scheme.group_colors, src_group, scheme.default_color)
    tgt_color = get(scheme.group_colors, tgt_group, scheme.default_color)
    
    if blend && src_group != tgt_group
        weighted_color_mean(0.5, src_color, tgt_color)
    else
        src_color
    end
end

function resolve_ribbon_color(
    scheme::CategoricalColorScheme,
    ribbon::Ribbon,
    cooc::AbstractChordData;
    blend::Bool = true
)
    src_idx = mod1(ribbon.source.label_idx, length(scheme.colors))
    tgt_idx = mod1(ribbon.target.label_idx, length(scheme.colors))
    
    if blend && src_idx != tgt_idx
        weighted_color_mean(0.5, scheme.colors[src_idx], scheme.colors[tgt_idx])
    else
        scheme.colors[src_idx]
    end
end

function resolve_ribbon_color(
    scheme::DivergingColorScheme,
    ribbon::Ribbon,
    cooc::AbstractChordData;
    blend::Bool = true  # ignored for diverging - color is by value
)
    # Color by ribbon value using diverging scale
    diverging_color(scheme, ribbon.value)
end

function resolve_arc_color(
    scheme::DivergingColorScheme,
    arc::ArcSegment,
    cooc::AbstractChordData
)
    # For arcs in diverging scheme, use neutral color (arcs don't have signed meaning)
    # Or could compute net flow - for now, neutral gray
    scheme.neutral_color
end

"""
    diverging_color(scheme::DivergingColorScheme, value::Real) -> RGB

Map a value to a color on the diverging scale.
"""
function diverging_color(scheme::DivergingColorScheme, value::Real)
    min_val, max_val = scheme.range
    
    # weighted_color_mean(w, c1, c2) returns w*c1 + (1-w)*c2
    # w=0 → c2, w=1 → c1
    
    if value ≤ 0
        # Negative side: neutral (at 0) to negative_color (at min_val)
        if min_val ≥ 0
            t = 0.0
        else
            t = clamp(value / min_val, 0.0, 1.0)  # t=0 at zero, t=1 at min_val
        end
        # t=0 -> neutral, t=1 -> negative_color
        # Use w=t with c1=negative, c2=neutral: w=0->neutral, w=1->negative ✓
        weighted_color_mean(t, scheme.negative_color, scheme.neutral_color)
    else
        # Positive side: neutral (at 0) to positive_color (at max_val)
        if max_val ≤ 0
            t = 0.0
        else
            t = clamp(value / max_val, 0.0, 1.0)  # t=0 at zero, t=1 at max_val
        end
        # t=0 -> neutral, t=1 -> positive_color
        # Use w=t with c1=positive, c2=neutral: w=0->neutral, w=1->positive ✓
        weighted_color_mean(t, scheme.positive_color, scheme.neutral_color)
    end
end

#==============================================================================#
# Color Utilities
#==============================================================================#

"""
    with_alpha(color::Colorant, alpha::Real)

Return color with specified alpha value.
"""
function with_alpha(color::Colorant, alpha::Real)
    RGBA(color, alpha)
end

"""
    darken(color::Colorant, factor::Real=0.2)

Darken a color by the given factor.
"""
function darken(color::Colorant, factor::Real = 0.2)
    RGB(
        color.r * (1 - factor),
        color.g * (1 - factor),
        color.b * (1 - factor)
    )
end

"""
    lighten(color::Colorant, factor::Real=0.2)

Lighten a color by the given factor.
"""
function lighten(color::Colorant, factor::Real = 0.2)
    RGB(
        color.r + (1 - color.r) * factor,
        color.g + (1 - color.g) * factor,
        color.b + (1 - color.b) * factor
    )
end
