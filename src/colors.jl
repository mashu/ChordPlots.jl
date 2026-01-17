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

#==============================================================================#
# Color Scheme Construction
#==============================================================================#

"""
    group_colors(cooc::CoOccurrenceMatrix; palette=:Set1)

Create a color scheme based on groups.
"""
function group_colors(cooc::CoOccurrenceMatrix; palette::Symbol = :Set1)
    n_groups = ngroups(cooc)
    colors = distinguishable_colors(n_groups, [RGB(1,1,1), RGB(0,0,0)], dropseed=true)
    
    group_color_dict = Dict{Symbol, RGB{Float64}}()
    for (i, group) in enumerate(cooc.groups)
        group_color_dict[group.name] = colors[i]
    end
    
    GroupColorScheme(group_color_dict, RGB(0.5, 0.5, 0.5))
end

"""
    categorical_colors(n::Int; palette=:Set1)

Create n distinguishable colors.
"""
function categorical_colors(n::Int; kwargs...)
    colors = distinguishable_colors(n, [RGB(1,1,1), RGB(0,0,0)], dropseed=true)
    CategoricalColorScheme(colors)
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

#==============================================================================#
# Color Resolution
#==============================================================================#

"""
    resolve_arc_color(scheme::AbstractColorScheme, arc::ArcSegment, cooc::CoOccurrenceMatrix)

Get the color for an arc based on the color scheme.
"""
function resolve_arc_color(
    scheme::GroupColorScheme,
    arc::ArcSegment,
    cooc::CoOccurrenceMatrix
)
    group = get_group(cooc, arc.label_idx)
    get(scheme.group_colors, group, scheme.default_color)
end

function resolve_arc_color(
    scheme::CategoricalColorScheme,
    arc::ArcSegment,
    cooc::CoOccurrenceMatrix
)
    idx = mod1(arc.label_idx, length(scheme.colors))
    scheme.colors[idx]
end

"""
    resolve_ribbon_color(scheme::AbstractColorScheme, ribbon::Ribbon, cooc::CoOccurrenceMatrix; blend=true)

Get the color for a ribbon. By default blends source and target colors.
"""
function resolve_ribbon_color(
    scheme::GroupColorScheme,
    ribbon::Ribbon,
    cooc::CoOccurrenceMatrix;
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
    cooc::CoOccurrenceMatrix;
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
