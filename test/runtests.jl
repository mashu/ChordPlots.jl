# test/runtests.jl
using Test
using ChordPlots
using DataFrames
using Colors

@testset "ChordPlots.jl" begin
    
    @testset "Types" begin
        @testset "GroupInfo" begin
            g = GroupInfo{String}(:test, ["a", "b", "c"], 1:3)
            @test length(g) == 3
            @test g.name == :test
            @test g.indices == 1:3
            
            # Iteration
            labels = collect(g)
            @test labels == ["a", "b", "c"]
        end
        
        @testset "ArcSegment" begin
            arc = ArcSegment{Float64}(1, 0.0, π/2, 10.0)
            @test arc.label_idx == 1
            @test arc_span(arc) ≈ π/2
            @test arc_midpoint(arc) ≈ π/4
        end
        
        @testset "RibbonEndpoint" begin
            ep = RibbonEndpoint{Float64}(1, 0.0, π/4)
            @test endpoint_span(ep) ≈ π/4
            @test endpoint_midpoint(ep) ≈ π/8
        end
        
        @testset "Ribbon" begin
            src = RibbonEndpoint{Float64}(1, 0.0, 0.1)
            tgt = RibbonEndpoint{Float64}(2, π, π+0.1)
            r = Ribbon{Float64}(src, tgt, 5.0)
            @test !is_self_loop(r)
            
            # Self-loop
            self = Ribbon{Float64}(src, src, 3.0)
            @test is_self_loop(self)
        end
    end
    
    @testset "CoOccurrenceMatrix Construction" begin
        @testset "From DataFrame" begin
            df = DataFrame(
                A = ["a1", "a1", "a2", "a2"],
                B = ["b1", "b2", "b1", "b2"],
                C = ["c1", "c1", "c2", "c2"]
            )
            
            cooc = cooccurrence_matrix(df, [:A, :B, :C])
            
            @test nlabels(cooc) == 6  # a1,a2 + b1,b2 + c1,c2
            @test ngroups(cooc) == 3
            
            # Check groups
            @test cooc.groups[1].name == :A
            @test cooc.groups[2].name == :B
            @test cooc.groups[3].name == :C
            
            # Check matrix is square
            @test size(cooc) == (6, 6)
        end
        
        @testset "Direct construction" begin
            matrix = [4 2 1; 2 3 2; 1 2 2]
            labels = ["x", "y", "z"]
            groups = [GroupInfo{String}(:G1, ["x", "y"], 1:2),
                     GroupInfo{String}(:G2, ["z"], 3:3)]
            
            cooc = CoOccurrenceMatrix(matrix, labels, groups)
            
            @test cooc["x", "y"] == 2
            @test cooc[1, 2] == 2
            @test total_flow(cooc, 1) == sum(matrix[1, :])
        end
        
        @testset "Normalization" begin
            df = DataFrame(A=["a", "a"], B=["b", "b"])
            cooc = cooccurrence_matrix(df, [:A, :B])
            norm_cooc = normalize(cooc)
            @test norm_cooc isa ChordPlots.NormalizedCoOccurrenceMatrix
            @test sum(norm_cooc.matrix) ≈ 1.0
        end
        
        @testset "NormalizedCoOccurrenceMatrix and mean_normalized" begin
            df = DataFrame(V=["V1", "V1", "V2"], D=["D1", "D2", "D1"], J=["J1", "J1", "J2"])
            cooc = cooccurrence_matrix(df, [:V, :D, :J])
            # Mean of same normalized matrix twice = same as normalize once
            mean_norm = mean_normalized([cooc, cooc])
            @test mean_norm isa ChordPlots.NormalizedCoOccurrenceMatrix
            @test sum(mean_norm.matrix) ≈ 1.0
            @test mean_norm.matrix ≈ normalize(cooc).matrix
            layout = compute_layout(mean_norm)
            @test narcs(layout) == nlabels(mean_norm)
        end
        
        @testset "mean_normalized with different labels per donor" begin
            df1 = DataFrame(V=["V1", "V1"], D=["D1", "D2"], J=["J1", "J1"])
            df2 = DataFrame(V=["V2", "V2"], D=["D1", "D1"], J=["J1", "J2"])
            cooc1 = cooccurrence_matrix(df1, [:V, :D, :J])
            cooc2 = cooccurrence_matrix(df2, [:V, :D, :J])
            @test cooc1.labels != cooc2.labels
            combined = mean_normalized([cooc1, cooc2])
            @test combined isa ChordPlots.NormalizedCoOccurrenceMatrix
            @test sum(combined.matrix) ≈ 1.0
            @test length(combined.labels) == 6
            @test "V1" in combined.labels && "V2" in combined.labels
        end
    end
    
    @testset "Layout Computation" begin
        df = DataFrame(
            V = ["V1", "V1", "V2"],
            D = ["D1", "D2", "D1"],
            J = ["J1", "J1", "J2"]
        )
        cooc = cooccurrence_matrix(df, [:V, :D, :J])
        
        @testset "Default layout" begin
            layout = compute_layout(cooc)
            
            @test narcs(layout) == nlabels(cooc)
            @test nribbons(layout) > 0
            @test layout.inner_radius < layout.outer_radius
        end
        
        @testset "Custom config" begin
            config = LayoutConfig(
                inner_radius = 0.5,
                outer_radius = 0.9,
                gap_fraction = 0.1
            )
            layout = compute_layout(cooc, config)
            
            @test layout.inner_radius == 0.5
            @test layout.outer_radius == 0.9
        end
        
        @testset "Ribbon filtering" begin
            layout = compute_layout(cooc)
            n_original = nribbons(layout)
            
            # Filter should reduce ribbons (or keep same if all above threshold)
            filtered = filter_ribbons(layout, 1.0)
            @test nribbons(filtered) <= n_original
        end
        
        @testset "Fixed label order" begin
            # Same data, fixed order of label indices -> reproducible layout for comparison
            order = [3, 1, 2, 4, 5, 6]  # permutation of 1:6
            config = LayoutConfig(label_order = order)
            layout = compute_layout(cooc, config)
            @test narcs(layout) == 6
            # First arc along the circle (smallest start_angle) should be for label 3
            first_label = argmin([a.start_angle for a in layout.arcs])
            @test first_label == 3
        end
        
        @testset "label_order() fetches order for reuse" begin
            # Get order as label names from one cooc, apply to another for comparable plots
            names_in_order = label_order(cooc)
            @test length(names_in_order) == nlabels(cooc)
            @test Set(names_in_order) == Set(cooc.labels)
            # Using that order in chordplot should be valid (same set)
            config = LayoutConfig(label_order = [cooc.label_to_index[l] for l in names_in_order])
            layout = compute_layout(cooc, config)
            @test narcs(layout) == 6
        end
    end
    
    @testset "Geometry" begin
        @testset "Arc points" begin
            points = arc_points(0.0, π/2, 1.0; n_points=5)
            @test length(points) == 5
            @test points[1] ≈ Point2f(1, 0) atol=1e-6
            @test points[end] ≈ Point2f(0, 1) atol=1e-6
        end
        
        @testset "Arc polygon" begin
            poly = arc_polygon(0.8, 1.0, 0.0, π/2; n_points=10)
            @test length(poly) == 20  # 10 outer + 10 inner
        end
        
        @testset "Ribbon path" begin
            src = RibbonEndpoint{Float64}(1, 0.0, 0.2)
            tgt = RibbonEndpoint{Float64}(2, π, π+0.2)
            ribbon = Ribbon{Float64}(src, tgt, 5.0)
            
            path = ribbon_path(ribbon, 0.8)
            @test length(path.points) > 0
            @test path.source_idx == 1
            @test path.target_idx == 2
        end
        
        @testset "Label position" begin
            arc = ArcSegment{Float64}(1, 0.0, π/4, 10.0)
            lp = label_position(arc, 1.0, 0.1)
            
            @test lp.point[1] > 0  # Right side of circle
            @test lp.point[2] > 0  # Upper half
        end
    end
    
    @testset "Colors" begin
        df = DataFrame(A=["a1", "a2"], B=["b1", "b2"])
        cooc = cooccurrence_matrix(df, [:A, :B])
        
        @testset "Group colors" begin
            cs = group_colors(cooc)
            @test cs isa GroupColorScheme
            @test haskey(cs.group_colors, :A)
            @test haskey(cs.group_colors, :B)
        end
        
        @testset "Categorical colors" begin
            cs = categorical_colors(5)
            @test length(cs.colors) == 5
        end
        
        @testset "Color resolution" begin
            cs = group_colors(cooc)
            arc = ArcSegment{Float64}(1, 0.0, 0.5, 1.0)
            color = resolve_arc_color(cs, arc, cooc)
            @test color isa RGB
        end
        
        @testset "Color utilities" begin
            c = RGB(0.5, 0.5, 0.5)
            
            ca = with_alpha(c, 0.5)
            @test ca isa RGBA
            @test alpha(ca) == 0.5
            
            dark = darken(c, 0.2)
            @test dark.r < c.r
            
            light = lighten(c, 0.2)
            @test light.r > c.r
        end
    end
    
    @testset "Edge Cases" begin
        @testset "Single group" begin
            df = DataFrame(A = ["a1", "a2", "a1"])
            cooc = cooccurrence_matrix(df, [:A])
            @test nlabels(cooc) == 2
            @test ngroups(cooc) == 1
        end
        
        @testset "Missing values" begin
            df = DataFrame(
                A = ["a1", missing, "a2"],
                B = ["b1", "b1", missing]
            )
            cooc = cooccurrence_matrix(df, [:A, :B])
            # Should handle missing gracefully
            @test nlabels(cooc) >= 2
        end
        
        @testset "Empty co-occurrence" begin
            # Labels that never co-occur
            matrix = [1 0; 0 1]
            labels = ["x", "y"]
            groups = [GroupInfo{String}(:G, labels, 1:2)]
            
            cooc = CoOccurrenceMatrix(matrix, labels, groups)
            layout = compute_layout(cooc)
            
            # Should still produce valid layout
            @test narcs(layout) == 2
        end
    end
    
    @testset "Type Stability" begin
        df = DataFrame(A=["a"], B=["b"])
        cooc = cooccurrence_matrix(df, [:A, :B])
        
        # These should not throw type instability warnings
        @inferred nlabels(cooc)
        @inferred ngroups(cooc)
        @inferred total_flow(cooc, 1)
        
        layout = compute_layout(cooc)
        @inferred narcs(layout)
        @inferred nribbons(layout)
    end
end

println("All tests passed!")
