using Documenter, LAS

push!(LOAD_PATH,"../src/")

makedocs(
    modules = [LAS],
    sitename = "LAS.jl Documentation",
    repo = "https://github.com/fugro-oss/LAS.jl",
    pages = ["Home" => "index.md"],
)

deploydocs(
    repo = "github.com/fugro-oss/LAS.jl",
    push_preview=true
)