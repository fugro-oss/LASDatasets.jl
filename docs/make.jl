using Documenter, LasDatasets

push!(LOAD_PATH,"../src/")

makedocs(
    modules = [LasDatasets],
    sitename = "LasDatasets.jl",
    pages = [
        "Home" => "index.md",
        "Interface" => "interface.md",
        "Header" => "header.md",
        "Points" => "points.md",
        "Variable Length Records" => "vlrs.md",
        "User Fields" => "user_fields.md",
        "Internals" => "internals.md",
        "API" => "api.md",
    ],
    warnonly = [:missing_docs, :autodocs_block, :docs_block, :cross_references]
)

deploydocs(
    repo = "github.com/fugro-oss/LasDatasets.jl.git",
    versions = ["stable" => "v^", "v#.#", "dev" => "main"],
    push_preview=true
)