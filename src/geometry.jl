# src/geometry.jl
# Geometric primitives: arcs, Bezier curves, and path generation

using GeometryBasics: Point2f, Vec2f

#==============================================================================#
# Basic Trigonometric Helpers
#==============================================================================#

"""
    angle_to_point(angle::Real, radius::Real) -> Point2f

Convert polar coordinates to Cartesian point.
"""
@inline function angle_to_point(angle::Real, radius::Real)
    Point2f(radius * cos(angle), radius * sin(angle))
end

"""
    angles_to_points(angles::AbstractVector, radius::Real) -> Vector{Point2f}

Convert multiple angles to Cartesian points.
"""
function angles_to_points(angles::AbstractVector{T}, radius::Real) where T<:Real
    [angle_to_point(a, radius) for a in angles]
end

#==============================================================================#
# Arc Generation
#==============================================================================#

"""
    arc_points(start_angle::Real, end_angle::Real, radius::Real; n_points::Int=50)

Generate points along an arc.

# Arguments
- `start_angle`: Start angle in radians
- `end_angle`: End angle in radians
- `radius`: Arc radius
- `n_points`: Number of points (more = smoother)

# Returns
- `Vector{Point2f}`: Points along the arc
"""
function arc_points(
    start_angle::Real,
    end_angle::Real,
    radius::Real;
    n_points::Int = 50
)::Vector{Point2f}
    angles = range(start_angle, end_angle, length=n_points)
    angles_to_points(angles, radius)
end

"""
    arc_polygon(inner_radius::Real, outer_radius::Real, start_angle::Real, end_angle::Real; n_points::Int=30)

Generate a filled arc (annular sector) as a polygon.

Returns points forming a closed polygon: outer arc → inner arc (reversed) → close.
"""
function arc_polygon(
    inner_radius::Real,
    outer_radius::Real,
    start_angle::Real,
    end_angle::Real;
    n_points::Int = 30
)::Vector{Point2f}
    outer = arc_points(start_angle, end_angle, outer_radius; n_points)
    inner = arc_points(end_angle, start_angle, inner_radius; n_points)  # Reversed
    vcat(outer, inner)
end

#==============================================================================#
# Bezier Curve Generation
#==============================================================================#

"""
    cubic_bezier(p0::Point2f, p1::Point2f, p2::Point2f, p3::Point2f, t::Real) -> Point2f

Evaluate cubic Bezier curve at parameter t ∈ [0, 1].
"""
@inline function cubic_bezier(
    p0::Point2f, p1::Point2f, p2::Point2f, p3::Point2f, t::Real
)::Point2f
    t1 = 1 - t
    t1^3 * p0 + 3 * t1^2 * t * p1 + 3 * t1 * t^2 * p2 + t^3 * p3
end

"""
    cubic_bezier_points(p0, p1, p2, p3; n_points::Int=30) -> Vector{Point2f}

Generate points along a cubic Bezier curve.
"""
function cubic_bezier_points(
    p0::Point2f, p1::Point2f, p2::Point2f, p3::Point2f;
    n_points::Int = 30
)::Vector{Point2f}
    [cubic_bezier(p0, p1, p2, p3, t) for t in range(0, 1, length=n_points)]
end

#==============================================================================#
# Ribbon Path Generation  
#==============================================================================#

"""
    RibbonPath

Stores the complete path for rendering a ribbon.
"""
struct RibbonPath
    points::Vector{Point2f}
    source_idx::Int
    target_idx::Int
end

"""
    ribbon_path(ribbon::Ribbon, radius::Real; n_bezier::Int=30, tension::Real=0.5)

Generate the path for a ribbon connecting two arcs.

The ribbon consists of:
1. Source arc segment
2. Bezier curve to target
3. Target arc segment  
4. Bezier curve back to source

# Arguments
- `ribbon`: Ribbon geometry specification
- `radius`: Radius where ribbons attach
- `n_bezier`: Points per Bezier curve
- `tension`: Control point tension (0 = straight, 1 = tight curves)
"""
function ribbon_path(
    ribbon::Ribbon{T},
    radius::Real;
    n_bezier::Int = 30,
    tension::Real = 0.5
)::RibbonPath where T
    
    src = ribbon.source
    tgt = ribbon.target
    
    # Source arc endpoints
    src_start = angle_to_point(src.start_angle, radius)
    src_end = angle_to_point(src.end_angle, radius)
    
    # Target arc endpoints  
    tgt_start = angle_to_point(tgt.start_angle, radius)
    tgt_end = angle_to_point(tgt.end_angle, radius)
    
    # Control points for Bezier curves (toward center with tension)
    center = Point2f(0, 0)
    ctrl_factor = radius * (1 - tension)
    
    # Control points for source→target curve
    src_end_ctrl = Point2f(
        ctrl_factor * cos(src.end_angle),
        ctrl_factor * sin(src.end_angle)
    )
    tgt_start_ctrl = Point2f(
        ctrl_factor * cos(tgt.start_angle),
        ctrl_factor * sin(tgt.start_angle)
    )
    
    # Control points for target→source curve
    tgt_end_ctrl = Point2f(
        ctrl_factor * cos(tgt.end_angle),
        ctrl_factor * sin(tgt.end_angle)
    )
    src_start_ctrl = Point2f(
        ctrl_factor * cos(src.start_angle),
        ctrl_factor * sin(src.start_angle)
    )
    
    # Build path
    path = Point2f[]
    
    # 1. Source arc (from start to end)
    if is_self_loop(ribbon)
        # Self-loop: draw two separate bezier curves meeting at center
        append!(path, arc_points(src.start_angle, src.end_angle, radius; n_points=n_bezier÷2))
        # Bezier to center and back
        mid_ctrl = Point2f(0, 0)
        src_mid = angle_to_point((src.start_angle + src.end_angle) / 2, radius)
        append!(path, cubic_bezier_points(src_end, tgt_start_ctrl, src_end_ctrl, src_start; n_points=n_bezier))
    else
        append!(path, arc_points(src.start_angle, src.end_angle, radius; n_points=n_bezier÷2))
        
        # 2. Bezier from source end to target start
        append!(path, cubic_bezier_points(src_end, src_end_ctrl, tgt_start_ctrl, tgt_start; n_points=n_bezier))
        
        # 3. Target arc (from start to end)
        append!(path, arc_points(tgt.start_angle, tgt.end_angle, radius; n_points=n_bezier÷2))
        
        # 4. Bezier from target end back to source start
        append!(path, cubic_bezier_points(tgt_end, tgt_end_ctrl, src_start_ctrl, src_start; n_points=n_bezier))
    end
    
    RibbonPath(path, src.label_idx, tgt.label_idx)
end

"""
    ribbon_paths(ribbons::Vector{Ribbon{T}}, radius::Real; kwargs...)

Generate paths for multiple ribbons.
"""
function ribbon_paths(
    ribbons::Vector{Ribbon{T}},
    radius::Real;
    kwargs...
)::Vector{RibbonPath} where T
    [ribbon_path(r, radius; kwargs...) for r in ribbons]
end

#==============================================================================#
# Label Positioning
#==============================================================================#

"""
    LabelPosition

Position and rotation for a label.
"""
struct LabelPosition
    point::Point2f
    angle::Float64      # Rotation angle
    halign::Symbol      # :left, :center, :right
    valign::Symbol      # :top, :center, :bottom
end

"""
    label_position(arc::ArcSegment, radius::Real, offset::Real; rotate::Bool=true)

Calculate position for an arc's label.
"""
function label_position(
    arc::ArcSegment{T},
    radius::Real,
    offset::Real;
    rotate::Bool = true
)::LabelPosition where T
    
    mid_angle = arc_midpoint(arc)
    label_radius = radius + offset
    point = angle_to_point(mid_angle, label_radius)
    
    # Determine alignment based on angle
    # Right half of circle: left-aligned labels
    # Left half: right-aligned labels
    if rotate
        # Rotate label to be tangent to circle
        if -π/2 <= mid_angle <= π/2
            rotation = mid_angle
            halign = :left
        else
            rotation = mid_angle + π  # Flip for readability
            halign = :right
        end
    else
        rotation = 0.0
        halign = :center
    end
    
    LabelPosition(point, rotation, halign, :center)
end

"""
    label_positions(arcs::Vector{ArcSegment{T}}, radius::Real, offset::Real; kwargs...)

Calculate positions for all arc labels.
"""
function label_positions(
    arcs::Vector{ArcSegment{T}},
    radius::Real,
    offset::Real;
    kwargs...
)::Vector{LabelPosition} where T
    [label_position(arc, radius, offset; kwargs...) for arc in arcs]
end
