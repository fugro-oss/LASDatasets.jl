"""
    $(TYPEDEF)

A LAS point record containing point data as well as any user-defined bytes specific to that point

$(TYPEDFIELDS)
"""
struct LasRecord{TPoint<:LasPoint{N} where N,NUserBytes}
    """Point data for this record"""
    point::TPoint

    """Extra bytes padded after a point record as defined by the user so that the total record length matches what is specified in the header"""
    user_bytes::SVector{NUserBytes,UInt8}
end

Base.:(==)(r1::LasRecord, r2::LasRecord) = (r1.point == r2.point) && (r1.user_bytes == r2.user_bytes)

LasRecord(point::TPoint) where TPoint = LasRecord{TPoint,0}(point, SVector{0,UInt8}())

Base.read(io::IO, ::Type{T}) where {TPoint, N, T <: LasRecord{TPoint, N}} = T(read_struct(io, TPoint), read(io, SVector{N,UInt8}))

function Base.write(io::IO, record::LasRecord{TPoint,N}) where {TPoint,N}
    write_struct(io, record.point);
    if (N > 0)
        write(io, record.user_bytes);
    end
end

function merge_fields!(original::LasRecord{TPoint,NUserBytes}, merge_in::TNewValues) where {TPoint,NUserBytes,TNewValues}

    fields = collect(fieldnames(TPoint))
    
    for field ∈ filter(f -> f ∈ fields, fieldnames(TNewValues))
        getfield(original.point, field) .= getfield(merge_in, field)
    end
end


function merge_fields!(original::StructVector{TRecord}, merge_in::StructVector{TNewValues}) where {TPoints,NUserBytes, TRecord <: LasRecord{TPoints, NUserBytes}, TNewValues}
    fields = collect(fieldnames(TPoints))
    for field ∈ filter(f -> f ∈ fields, fieldnames(TNewValues))
        getproperty(original.point, field) .= getproperty(merge_in, field)
    end
end

Base.vcat(records::Vararg{TRecord,N}) where {N, NUserBytes, TPoints, TRecord <: LasRecord{TPoints, NUserBytes}} = TRecord(TPoint(map(field -> reduce(vcat, getfield.(getfield.(records, :point), Ref(field))), fieldnames(TPoints))...), reduce(vcat, getfield.(records, Ref(:user_bytes))))

laspoint(::Type{TPoint}, p::TRecord, xyz::SpatialInfo) where {TPoint, N, TRecord <: LasRecord{TPoint, N}} = p.point

function byte_size(record::Type{TRecord}) where TRecord <: LasRecord{TPoint,N} where {N, TPoint <: LasPoint{F}} where F
    return byte_size(TPoint) + N
end