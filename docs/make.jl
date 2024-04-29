using Documenter, LAS

push!(LOAD_PATH,"../src/")

makedocs(
    modules = [LAS],
    sitename = "LAS.jl",
    repo = "https://github.com/fugro-oss/LAS.jl",
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
    repo = "github.com/fugro-oss/LAS.jl.git",
    versions = ["stable" => "v^", "v#.#", "dev" => "main"],
    push_preview=true
)