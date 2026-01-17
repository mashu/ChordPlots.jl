using Pkg
Pkg.activate(".")

# Develop the local package (not registered)
# @__DIR__ is docs/, so go up one level to get package root
docs_dir = @__DIR__
root_dir = dirname(docs_dir)
Pkg.develop(PackageSpec(path=root_dir))

Pkg.instantiate()

using Documenter
using ChordPlots
using CairoMakie
using DataFrames
using Random

# Set up for headless plotting
CairoMakie.activate!(type = "png")

# Generate example plots before building docs
include(joinpath(@__DIR__, "generate_examples.jl"))

makedocs(
    sitename = "ChordPlots.jl",
    authors = "Mateusz Kaduk",
    modules = [ChordPlots],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://mashu.github.io/ChordPlots.jl",
        assets = ["assets/custom.css"],
        size_threshold = 512 * 1024,  # 512KB
    ),
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "User Guide" => [
            "Creating Data" => "user_guide/creating_data.md",
            "Basic Plotting" => "user_guide/basic_plotting.md",
            "Customization" => "user_guide/customization.md",
            "Filtering" => "user_guide/filtering.md",
            "Color Schemes" => "user_guide/colors.md",
            "Layout Configuration" => "user_guide/layout.md",
        ],
        "Examples" => [
            "Basic Example" => "examples/basic.md",
        ],
        "API Reference" => "api.md",
    ],
    checkdocs = :none,  # Don't fail on missing docstrings
)

deploydocs(
    repo = "github.com/mashu/ChordPlots.jl.git",
    devbranch = "main",
    push_preview = true,
    versions = ["stable" => "v^", "v#.#", "dev" => "dev"],
)
