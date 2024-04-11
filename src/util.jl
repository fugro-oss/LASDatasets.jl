"""
    $(TYPEDSIGNATURES)

Read a string from `nb` bytes from an IO channel `io`
"""
function readstring(io, nb::Integer)
    bytes = read(io, nb)
    # strip possible null bytes
    lastchar = findlast(bytes .!= 0)
    if isnothing(lastchar)
        return ""
    else
        return String(bytes[1:lastchar])
    end
end

"""
    $(TYPEDSIGNATURES)

Write a string `str` to an IO channel `io`, writing exactly `nb` bytes (padding if `str` is too short)
"""
function writestring(io, str::AbstractString, nb::Integer)
    n = length(str)
    npad = nb - n
    @assert npad ≥ 0 "String length $(n) exceeds number of bytes $(nb)"
    if npad == 0
        write(io, str)
    else
        writestr = string(str * "\0"^npad)
        write(io, writestr)
    end
end
# skip the LAS file's magic four bytes, "LASF"
skiplasf(s::Union{Stream{format"LAS"}, Stream{format"LAZ"}, IO}) = readstring(s, 4)

function open_las(func::Function, file::String, rw::String = "r")
    @assert rw == "r" || rw == "w" "IO flags must be read (r) or write (w)"
    wrapper = rw == "r" ? BufferedInputStream : BufferedOutputStream
    io = wrapper(open(file, rw))
    try
        return func(io)
    finally
        close(io)
    end
end

is_laz(file_name::AbstractString) = endswith(file_name, ".laz")

function denormalize(::Type{T}, value::Real) where {T <: Integer}
    return floor(T, typemax(T) * clamp(value, 0.0, 1.0))
end

function denormalize(::Type{T}, value::Normed{T,N}) where {T <: Integer, N}
    return value.i
end

macro check(obj, ex)
    return :($(esc(ex)) == 0 ? nothing : laszip_error($(esc(obj))))
end

function laszip_error(laszip_obj::Ptr{Cvoid})
    errstr = Ref(Cstring(C_NULL))
    laszip_get_error(laszip_obj, errstr)
    if errstr[] != C_NULL
        error(unsafe_string(errstr[]))
    end
    nothing
end

function software_version()
    laspoints_version = read_project(joinpath( dirname(@__FILE__()), "..", "Project.toml")).version
    return "LAS.jl v$(laspoints_version)"
end