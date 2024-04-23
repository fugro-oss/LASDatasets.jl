"""
    $(TYPEDEF)

A collection of user-defined non-standard point fields in LAS
These will be documented in the "Extra Bytes" VLR of your LAS file

$(TYPEDFIELDS)
---
$(METHODLIST)
"""
struct UserFields{Names, Types}
    """Mapping of field names to values. Note that values must match the corresponding field type included in the `UserFields` `Type` parameter"""
    values::Dict{Symbol, Any}

    function UserFields{Names, Types}(values::Dict{Symbol, Any}) where {Names, Types}
        ks = Tuple(collect(keys(values)))
        types = Tuple{map(k -> typeof(values[k]), ks)...}
        @assert ks == Names
        @assert types == Types
        return new{Names, Types}(values)
    end

    function UserFields(values::Dict{Symbol, Any})
        ks = Tuple(collect(keys(values)))
        types = Tuple{map(k -> typeof(values[k]), ks)...}
        return new{ks, types}(values)
    end
end

function UserFields(fields::Vararg{Pair{Symbol}, N}) where N
    return UserFields(Dict{Symbol, Any}(fields))
end

function Base.:(==)(u1::UserFields{N, T}, u2::UserFields{M, S}) where {N, M, T, S}
    all([
        N == M,
        T == S,
        u1.values == u2.values
    ])
end

Base.sizeof(::Type{UserFields{Names, Types}}) where {Names, Types} = sum(sizeof.(Types))

# overloaded so we can access user fields in a struct array (see read functions)
function Base.getproperty(u::UserFields, field::Symbol)
    vals = getfield(u, :values)
    @assert field ∈ keys(vals) "Field $(field) not present!"
    vals[field]
end

function get_data_type(::UserFields{Names, Types}, field::Symbol) where {Names, Types}
    idx = findfirst(Names .== field)
    @assert !isnothing(idx) "Field $(field) not present"
    return fieldtypes(Types)[idx]
end

function Base.setproperty!(u::UserFields, field::Symbol, value::T) where {T}
    vals = getfield(u, :values)
    @assert field ∈ keys(vals) "Field $(field) not present!"
    existsing_type = get_data_type(u, field)
    vals[field] = convert(existsing_type, value)
end

Base.propertynames(::Type{UserFields{Names, Types}}) where {Names, Types} = Names
data_types(::Type{UserFields{Names, Types}}) where {Names, Types} = Types

function Base.show(io::IO, u::UserFields{Names, Types}) where {Names, Types}
    print(io, "UserFields(")
    for i ∈ eachindex(Names)
        print(io, "$(Names[i])::$(fieldtypes(Types)[i])=$(getproperty(u, Names[i]))")
        if i != length(Names)
            print(io, ",")
        end
    end
    print(io, ")")
end

function Base.read(io::IO, ::Type{UserFields{Names, Types}}) where {Names, Types}
    UserFields(map(i -> Names[i] => read(io, fieldtypes(Types)[i]), eachindex(Names))...)
end

StructArrays.staticschema(::Type{UserFields{Names, Types}}) where {Names, Types} = NamedTuple{Names, Types}

StructArrays.component(u::UserFields, key::Symbol) = Base.getproperty(u, key)

function StructArrays.createinstance(::Type{UserFields{Names, Types}}, args...) where {Names, Types}
    @assert length(args) == length(Names) "Number of fields $(length(Names)) doesn't match number of provided arguments $(length(args))"
    data_types = fieldtypes(Types)
    return UserFields(map(i -> Names[i] => convert(data_types[i], args[i]), eachindex(args))...)
end

"""
    $(TYPEDEF)

An abstract form of a LAS record. These are points with some additional information possibly included
"""
abstract type LasRecord end

"""
    $(TYPEDSIGNATURES)

Helper function to get the LAS point from a LAS point record

$(METHODLIST)
"""
get_point(record::LasRecord) = record.point

"""
    $(TYPEDSIGNATURES)

Helper function to get the LAS point format associated with a LAS point record

$(METHODLIST)
"""
function get_point_format end

"""
    $(TYPEDSIGNATURES)

Helper function to get the number of bytes making up user-defined fields associated with a LAS point record

$(METHODLIST)
"""
function get_num_user_field_bytes end

"""
    $(TYPEDSIGNATURES)

Helper function to get the number of undocumented extra bytes associated with a LAS point record

$(METHODLIST)
"""
function get_num_undocumented_bytes end

"""
    $(TYPEDEF)

A LAS record that only has a point

$(TYPEDFIELDS)
"""
struct PointRecord{TPoint} <: LasRecord
    """The LAS point stored in this record"""
    point::TPoint
end

function PointRecord(point::TPoint) where {TPoint <: LasPoint}
    PointRecord{TPoint}(point)
end

Base.read(io::IO, ::Type{PointRecord{TPoint}}) where {TPoint <: LasPoint} = PointRecord(read_struct(io, TPoint))

get_point_format(::Type{PointRecord{TPoint}}) where TPoint = TPoint
get_num_user_field_bytes(::Type{TRecord}) where {TRecord <: PointRecord} = 0
get_num_undocumented_bytes(::Type{TRecord}) where {TRecord <: PointRecord} = 0

"""
    $(TYPEDEF)

A LAS record that has a LAS point and extra user-defined point fields. 
Note that these must be documented as `ExtraBytes` VLRs in the LAS file

$(TYPEDFIELDS)
"""
struct ExtendedPointRecord{TPoint, Names, Types} <: LasRecord
    """The LAS point stored in this record"""
    point::TPoint

    """Extra user fields associated with this point"""
    user_fields::UserFields{Names, Types}
end

function ExtendedPointRecord(point::TPoint, user_fields::UserFields{Names, Types}) where {TPoint <: LasPoint, Names, Types}
    ExtendedPointRecord{TPoint, Names, Types}(point, user_fields)
end

function Base.read(io::IO, ::Type{ExtendedPointRecord{TPoint, Names, Types}}) where {TPoint <: LasPoint, Names, Types}
    point = read_struct(io, TPoint)
    user_fields = read(io, UserFields{Names, Types})
    return ExtendedPointRecord(point, user_fields)
end

get_point_format(::Type{ExtendedPointRecord{TPoint, Names, Types}}) where {TPoint, Names, Types} = TPoint
get_num_user_field_bytes(::Type{TRecord}) where {TRecord <: ExtendedPointRecord} = sum(sizeof.(get_user_field_types(TRecord)))
get_user_field_names(::Type{ExtendedPointRecord{TPoint, Names, Types}}) where {TPoint, Names, Types} = collect(Names)
get_user_field_types(::Type{ExtendedPointRecord{TPoint, Names, Types}}) where {TPoint, Names, Types} = fieldtypes(Types)
get_num_undocumented_bytes(::Type{TRecord}) where {TRecord <: ExtendedPointRecord} = 0

"""
    $(TYPEDEF)

A LAS record that has a point as well as additional undocumented bytes (i.e. that don't have an associated `ExtraBytes` VLR)

$(TYPEDFIELDS)
"""
struct UndocPointRecord{TPoint, N} <: LasRecord
    """The LAS point stored in this record"""
    point::TPoint

    """Array of extra bytes after the point that haven't been documented in the VLRs"""
    undoc_bytes::SVector{N, UInt8}
end

function UndocPointRecord(point::TPoint, undoc_bytes::SVector{N, UInt8}) where {TPoint <: LasPoint, N}
    UndocPointRecord{TPoint, N}(point, undoc_bytes)
end

function Base.read(io::IO, ::Type{UndocPointRecord{TPoint, N}}) where {TPoint <: LasPoint, N}
    point = read(io, TPoint)
    undoc_bytes = SVector{N}(read(io, N))
    return UndocPointRecord(point, undoc_bytes)
end

get_point_format(::Type{UndocPointRecord{TPoint, N}}) where {TPoint, N} = TPoint
get_num_user_field_bytes(::Type{UndocPointRecord}) = 0
get_num_undocumented_bytes(::Type{UndocPointRecord{TPoint, N}}) where {TPoint, N} = N
get_undocumented_bytes(record::UndocPointRecord) = record.undoc_bytes

"""
    $(TYPEDEF)

A LAS record that has a LAS point, extra user-defined fields and additional undocumented extra bytes

$(TYPEDFIELDS)
"""
struct FullRecord{TPoint, Names, Types, N} <: LasRecord
    """The LAS point stored in this record"""
    point::TPoint

    """Extra user fields associated with this point"""
    user_fields::UserFields{Names, Types}

    """Array of extra bytes after the point that haven't been documented in the VLRs"""
    undoc_bytes::SVector{N, UInt8}
end

function FullRecord(point::TPoint, user_fields::UserFields{Names, Types}, undoc_bytes::SVector{N, UInt8}) where {TPoint <: LasPoint, Names, Types, N}
    FullRecord{TPoint, Names, Types, N}(point, user_fields, undoc_bytes)
end

get_point_format(::Type{FullRecord{TPoint, Names, Types, N}}) where {TPoint, Names, Types, N} = TPoint
get_num_user_field_bytes(::Type{TRecord}) where {TRecord <: FullRecord} = sum(sizeof.(get_user_field_types(TRecord)))
get_user_field_names(::Type{FullRecord{TPoint, Names, Types, N}}) where {TPoint, Names, Types, N} = collect(Names)
get_user_field_types(::Type{FullRecord{TPoint, Names, Types, N}}) where {TPoint, Names, Types, N} = fieldtypes(Types)
get_num_undocumented_bytes(::Type{FullRecord{TPoint, Names, Types, N}}) where {TPoint, Names, Types, N} = N
get_undocumented_bytes(record::FullRecord) = record.undoc_bytes

function Base.read(io::IO, ::Type{FullRecord{TPoint, Names, Types, N}}) where {TPoint <: LasPoint, Names, Types, N}
    point = read_struct(io, TPoint)
    user_fields = read(io, UserFields{Names, Types})
    undoc_bytes = SVector{N}(read(io, N))
    return FullRecord(point, user_fields, undoc_bytes)
end

"""
    $(TYPEDSIGNATURES)

Construct a LAS record for a point in a tabular point cloud

# Arguments
* `TPoint` : Type of the LAS point to construct from this point data
* `p` : Point entry in a tabular point cloud
* `xyz` : Spatial information about scaling, offsets and bounding ranges of the point cloud
* `user_fields` : Tuple of user-defined fields to append to the point record (empty if not using). Note: these must match what's in your point `p`. Default `()`
"""
function las_record(::Type{TPoint}, p::NamedTuple, xyz::SpatialInfo, undoc_bytes::SVector{N, UInt8}, user_fields = ()) where {TPoint <: LasPoint, N}
    point = laspoint(TPoint, p, xyz)
    if isempty(user_fields)
        if N == 0
            return PointRecord(point)
        else
            return UndocPointRecord(point, undoc_bytes)
        end
    else
        user_fields = UserFields(map(field -> field => getproperty(p, field), user_fields)...)
        if N == 0
            return ExtendedPointRecord(point, user_fields)
        else
            return FullRecord(point, user_fields, undoc_bytes)
        end
    end
end

get_column(extractor::Extractor, record::LasRecord) = get_column(extractor, get_point(record))

byte_size(::Type{TRecord}) where {TRecord <: LasRecord} = byte_size(get_point_format(TRecord)) + get_num_user_field_bytes(TRecord) + get_num_undocumented_bytes(TRecord)

"""
    $(TYPEDSIGNATURES)

Get the appropriate LAS record format for a LAS `header` and a (possibly empty) set of `extra_bytes` that document any optional user fields to include
"""
function record_format(header::LasHeader, extra_bytes::Vector{<:ExtraBytes} = ExtraBytes[])
    point_type = point_format(header)
    record_length = point_record_length(header)
    num_point_bytes = byte_size(point_type)
    record_diff = record_length - num_point_bytes
    @assert record_diff ≥ 0 "Record length in header $(record_length)B is smaller than point size $(num_point_bytes)B"
    if record_diff == 0
        return PointRecord{point_type}
    elseif isempty(extra_bytes)
        return UndocPointRecord{point_type, record_diff}
    end
    user_field_names = Tuple(Symbol.(name.(extra_bytes)))
    user_field_types = data_type.(extra_bytes)
    num_user_bytes = sum(sizeof.(user_field_types))
    num_undoc_bytes = record_length - num_point_bytes - num_user_bytes
    @assert num_undoc_bytes ≥ 0 "Record length of $(record_length)B in header is inconsistent with size of point $(num_point_bytes)B and size of user fields $(num_user_bytes)B"
    if num_undoc_bytes > 0
        return FullRecord{point_type, user_field_names, Tuple{user_field_types...}, num_undoc_bytes}
    else
        return ExtendedPointRecord{point_type, user_field_names, Tuple{user_field_types...}}
    end
end