using Documenter, LAS

push!(LOAD_PATH,"../src/")

makedocs(
    modules = [LAS],
    sitename = "LAS.jl",
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
    push_preview=true
)