struct AxisInfo{T}
    x::T
    y::T
    z::T
end

Base.:(==)(a1::AxisInfo, a2::AxisInfo) = all([a1.x == a2.x, a1.y == a2.y, a1.z == a2.z])

function Base.read(io::IO, ::Type{AxisInfo{T}}) where T
    x = read(io, T)
    y = read(io, T)
    z = read(io, T)
    return AxisInfo{T}(x, y, z)
end

function Base.write(io::IO, info::AxisInfo) 
    write(io, info.x)
    write(io, info.y)
    write(io, info.z) 
end

struct Range{T}
    max::T
    min::T

    function Range{T}(max::T, min::T) where T
        @assert max ≥ min "Max value $(max) is < min value $(min)"
        return new{T}(max, min)
    end
end

Range(max::T, min::T) where T = Range{T}(max, min)

Base.:(==)(r1::Range, r2::Range) = (r1.max == r2.max) && (r1.min == r2.min)
Base.isapprox(r1::Range, r2::Range) = (r1.max ≈ r2.max) && (r1.min ≈ r2.min)

Base.in(x::S, r::Range{T}) where {S <: Real, T <: Real} = (T(x) ≤ r.max) && (T(x) ≥ r.min)

function Base.read(io::IO, ::Type{Range{T}}) where T
    max = read(io, T)
    min = read(io, T)
    return Range{T}(max, min)
end

function Base.write(io::IO, range::Range) 
    write(io, range.max)
    write(io, range.min)
end

"""
    $(TYPEDEF)

A wrapper around the spatial information for points in a LAS dataset, specifically the bounding box, overall translation and scaling factors applied to each point
"""
struct SpatialInfo
    scale::AxisInfo{Float64}
    offset::AxisInfo{Float64}
    range::AxisInfo{Range{Float64}}
end

function Base.:(==)(s1::SpatialInfo, s2::SpatialInfo) 
    return all(map(property -> getproperty(s1, property) == getproperty(s2, property), fieldnames(SpatialInfo)))
end

@reflect SpatialInfo
Base.read(io::IO, ::Type{SpatialInfo}) = read_struct(io, SpatialInfo)
Base.write(io::IO, info::SpatialInfo) = write_struct(io, info)

const DEFAULT_SPATIAL_INFO = SpatialInfo(AxisInfo(POINT_SCALE, POINT_SCALE, POINT_SCALE), AxisInfo(0.0, 0.0, 0.0), AxisInfo(Range(Inf, -Inf), Range(Inf, -Inf), Range(Inf, -Inf)))

function bounding_box(points::AbstractVector{SVector{3, T}}) where {T <: Real}
    x_min = typemax(T)
    x_max = typemin(T)
    y_min = typemax(T)
    y_max = typemin(T)
    z_min = typemax(T)
    z_max = typemin(T)

    @inbounds for p ∈ points
        x = p[1]
        y = p[2]
        z = p[3]

        if x < x_min
            x_min = x
        end
        if y < y_min
            y_min = y
        end
        if x > x_max
            x_max = x
        end
        if y > y_max
            y_max = y
        end
        if z < z_min
            z_min = z
        end
        if z > z_max
            z_max = z
        end
    end
    return (; xmin = x_min, ymin = y_min, zmin = z_min, xmax = x_max, ymax = y_max, zmax = z_max)
end

get_spatial_info(points::AbstractVector{SVector{3, T}}, scale::T = T(POINT_SCALE)) where {T <: Real} = get_spatial_info(points, AxisInfo{T}(scale, scale, scale))
get_spatial_info(points::AbstractVector{SVector{3, T}}, scale::SVector{3, T}) where {T <: Real} = get_spatial_info(points, AxisInfo{T}(scale.x, scale.y, scale.z))

function get_spatial_info(points::AbstractVector{SVector{3, T}}, scale::AxisInfo{T}) where {T <: Real}
    bb = bounding_box(points)

    x_offset = determine_offset(bb.xmin, bb.xmax, scale.x)
    y_offset = determine_offset(bb.ymin, bb.ymax, scale.y)
    z_offset = determine_offset(bb.zmin, bb.zmax, scale.z)

    offset = AxisInfo(x_offset, y_offset, z_offset)

    x_min = scale.x * round((bb.xmin / scale.x) - 0.5)
    y_min = scale.y * round((bb.ymin / scale.y) - 0.5)
    z_min = scale.z * round((bb.zmin / scale.z) - 0.5)
    x_max = scale.x * round((bb.xmax / scale.x) + 0.5)
    y_max = scale.y * round((bb.ymax / scale.y) + 0.5)
    z_max = scale.z * round((bb.zmax / scale.z) + 0.5) 

    return SpatialInfo(scale, offset, AxisInfo(Range(x_max, x_min), Range(y_max, y_min), Range(z_max, z_min)))
end

get_spatial_info(pc::Union{AbstractVector{<:NamedTuple}, FlexTable}, scale::Union{Real, SVector, AxisInfo} = POINT_SCALE) = get_spatial_info(pc.position, scale)

function determine_offset(min_value, max_value, scale; threshold=10^7)
    s = round(Int64, ((min_value + max_value) / 2) / scale / threshold)
    s *= threshold * scale
    # Try to convert back and forth and check overflow
    (muladd(round(Int32, (min_value - s) / scale), scale, s) > 0) == (min_value > 0) || error("Can't fit offset for min with this scale, try to coarsen it.")
    (muladd(round(Int32, (max_value - s) / scale), scale, s) > 0) == (max_value > 0) || error("Can't fit offset for max with this scale, try to coarsen it.")
    s
end