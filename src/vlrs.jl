"""
    $(TYPEDEF)

A variable length record included in a LAS file. This stores a particular data type `TData` in the record, which can be
a known VLR such as a WKT transform or a custom struct.
To properly define I/O methods for VLR's of custom structs, you must register which user and record ID's this struct type 
will use using 

```julia
@register_vlr_type TData user_id record_ids
```

And overload the methods `read_vlr_data` and `write_vlr_data` for your type `TData`

See the LAS v1.4 spec [here](https://www.asprs.org/wp-content/uploads/2019/03/LAS_1_4_r14.pdf#subsection.0.2.5) for more details.

$(TYPEDFIELDS)
"""
mutable struct LasVariableLengthRecord{TData}
    """A reserved value for a VLR. Must be set to 0 for LAS v1.4 and 0xAABB for earlier versions"""
    const reserved::UInt16

    """String ID assigned by the user to this record type"""
    const user_id::String
    
    """Numerical ID assigned to this record type"""
    record_id::UInt16

    """A description of what the record is/is used for"""
    const description::String

    """The data stored in this record"""
    const data

    """Flag indicating whether this VLR is extended or not. EVLR's can carry a larger payload of 8 bytes"""
    const extended::Bool

    function LasVariableLengthRecord{TData}(reserved::UInt16, user_id::String, record_id::Integer, description::String, data, extended::Bool) where TData
        max_num_data_bytes = extended ? typemax(UInt64) : typemax(UInt16)
        @assert sizeof(data) ≤ max_num_data_bytes "Record is too long! Got $(length(data)) bytes when we can only have $(max_num_data_bytes) bytes!"

        check_data_against_record_id(data, user_id, record_id, extended)
        
        return new{TData}(reserved, user_id, record_id, description, data, extended)
    end
end

function LasVariableLengthRecord(reserved::UInt16, user_id::String, record_id::Integer, description::String, data::TData, extended::Bool) where TData
    return LasVariableLengthRecord{TData}(reserved, user_id, record_id, description, data, extended)
end

function LasVariableLengthRecord(user_id::String, record_id::Integer, description::String, data, extended::Bool = false)
    return LasVariableLengthRecord(zero(UInt16), user_id, record_id, description, data, extended)
end

"""
    $(TYPEDSIGNATURES)

Check that the `user_id` and `record_id` given are appropriate for a known VLR type data entry `data`
"""
function check_data_against_record_id(data, user_id::String, record_id::Integer, extended::Bool)
    data_type = typeof(data)
    if (user_id == LAS_SPEC_USER_ID) && (record_id != ID_SUPERSEDED)
        if extended
            if data_type == WaveformDataPackets
                @assert record_id == ID_WAVEFORMPACKETDATA "Record ID for Waveform Packets Data EVLR must be $(ID_WAVEFORMPACKETDATA)"
            end
        else
            if data_type == GeoKeys
                @assert record_id == ID_GEOKEYDIRECTORYTAG "Record ID for GeoKeys directory must be $(ID_GEOKEYDIRECTORYTAG)"
            elseif data_type == GeoDoubleParamsTag
                @assert record_id == ID_GEODOUBLEPARAMSTAG "Record ID for GeoDoubleParamsTag must be $(ID_GEODOUBLEPARAMSTAG)"
            elseif data_type == GeoAsciiParamsTag
                @assert record_id == ID_GEOASCIIPARAMSTAG "Record ID for GeoAsciiParamsTag must be $(ID_GEOASCIIPARAMSTAG)"
            elseif data_type == ClassificationLookup
                @assert record_id == ID_CLASSLOOKUP "Record ID for Classification Lookup must be $(ID_CLASSLOOKUP)"
            elseif data_type == TextAreaDescription
                @assert record_id == ID_TEXTDESCRIPTION "Record ID for text area description must be $(ID_TEXTDESCRIPTION)"
            elseif data_type <: ExtraBytes
                @assert record_id == ID_EXTRABYTES "Record ID for Extra Bytes must be $(ID_EXTRABYTES)"
            elseif typeof(data) == WaveformPacketDescriptor
                @assert 99 < record_id < 355 "Waveform packet descriptors must have record IDs between 100 and 354"
            end
        end
    end
end

# size of a VLR in bytes
Base.sizeof(vlr::LasVariableLengthRecord) = (vlr.extended ? 60 : 54) + sizeof(vlr.data)

function Base.:(==)(v1::LasVariableLengthRecord{T}, v2::LasVariableLengthRecord{S}) where {T, S}
    ((T <: S) || (S <: T)) && all(f -> getfield(v1, f) == getfield(v2, f), fieldnames(LasVariableLengthRecord))
end

# some helper methods to access fields
get_user_id(vlr::LasVariableLengthRecord) = vlr.user_id
get_record_id(vlr::LasVariableLengthRecord) = vlr.record_id
get_description(vlr::LasVariableLengthRecord) = vlr.description
get_data(vlr::LasVariableLengthRecord) = vlr.data
is_extended(vlr::LasVariableLengthRecord) = vlr.extended

"""
    $(TYPEDSIGNATURES)

Mark a VLR as "superseded", meaning it has been replaced by a newer record when modifying the LAS file.
Note: The LAS spec only allows for 1 superseded record per LAS file
"""
function set_superseded!(vlr::LasVariableLengthRecord)
    check_data_against_record_id(get_data(vlr), get_user_id(vlr), ID_SUPERSEDED, is_extended(vlr))
    vlr.record_id = ID_SUPERSEDED
end

"""
    $(TYPEDSIGNATURES)

The registered user ID associated to VLRs of this record type `TData`. Currently assuming one user ID per data type
"""
official_user_id(::Type{TData}) where TData = error("Official user ID not set for VLRs with data type $(TData)")

"""
    $(TYPEDSIGNATURES)

The registered record IDs associated to VLRs of this record type `TData`
"""
official_record_ids(::Type{TData}) where TData = error("Official record IDs not set for VLRs with data type $(TData)")

"""
    $(TYPEDSIGNATURES)

Get the data type associated with a particular `user_id` and `record_id`. 
This is used to automatically parse VLR data types on reading
"""
data_type_from_ids(::Val{User}, ::Val{Record}) where {User, Record} = Vector{UInt8}

# convenience function so you don't have to worry about wrapping Vals
data_type_from_ids(user_id::String, record_id::Integer) = data_type_from_ids(Val(Symbol(user_id)), Val(record_id))

"""
    $(TYPEDSIGNATURES)

Register a new VLR data type `type` by associating it with an official `user_id` and set of `record_ids` 
"""
macro register_vlr_type(type, user_id, record_ids)
    return quote
        this_record_ids = $(esc(record_ids))
        
        # restrict types for inputs
        if !($(esc(type)) isa DataType) && !($(esc(type)) isa UnionAll)
            throw(AssertionError("Type must be a DataType, not $(typeof($(esc(type))))"))
        end
        
        if !($(esc(user_id)) isa AbstractString)
            throw(AssertionError("User ID must be a String, not $(typeof($(esc(user_id))))"))
        elseif Base.sizeof($(esc(user_id))) > 16
            throw(AssertionError("User ID must be at most 16 bytes in length! Got $(Base.sizeof($(esc(user_id)))) bytes"))
        end
        
        if !(this_record_ids isa AbstractVector{<:Integer})
            # if we've only entered a single number, put it in an array and carry on
            if this_record_ids isa Integer
                this_record_ids = [this_record_ids]
            else
                throw(AssertionError("Record IDs must be a vector of Integers, not $(typeof(this_record_ids))"))
            end
        end 

        LASDatasets.official_record_ids(::Type{$(esc(type))}) = this_record_ids
        LASDatasets.official_user_id(::Type{$(esc(type))}) = $(esc(user_id))

        # for each combination of (user_id, record_id), make a method to get the expected data type for that combination
        for id ∈ this_record_ids
            LASDatasets.data_type_from_ids(::Val{Symbol($(esc(user_id)))}, ::Val{id}) = $(esc(type))
        end
    end
end

"""
    $(TYPEDSIGNATURES)

Read data of type `TData` that belongs to a VLR by readig `nb` bytes from an `io`. 
By default this will call `Base.read`, but for more specific read methods this will need to be overloaded for your type
"""
function read_vlr_data(io::IO, ::Type{TData}, nb::Integer) where TData
    return read(io, TData)
end

read_vlr_data(io::IO, ::Type{Vector{UInt8}}, nb::Integer) = read(io, nb)

"""
    $(TYPEDSIGNATURES)

Write data of type `TData` that belongs to a VLR to an `io`. 
By default this will call `Base.write`, but for more specific write methods this will need to be overloaded for your type
"""
function write_vlr_data(io::IO, data::TData) where TData
    return write(io, data)
end

function Base.read(io::IO, ::Type{LasVariableLengthRecord}, extended::Bool=false)
    # `reserved` is meant to be 0 according to the LAS spec 1.4, but earlier
    # versions set it to 0xAABB.  Whatever, I guess we just store&ignore for now.
    # See https://groups.google.com/forum/#!topic/lasroom/SVtNBA2y9iI
    reserved = read(io, UInt16)
    user_id = readstring(io, 16)
    record_id = read(io, UInt16)
    record_data_length::Int = extended ? read(io, UInt64) : read(io, UInt16)
    description = readstring(io, 32)
    data_type_to_read = data_type_from_ids(user_id, record_id)
    data = read_vlr_data(io, data_type_to_read, record_data_length)
    LasVariableLengthRecord(
        reserved,
        user_id,
        record_id,
        description,
        data,
        extended
    )
end

function Base.write(io::IO, vlr::LasVariableLengthRecord)
    write(io, vlr.reserved)
    writestring(io, vlr.user_id, 16)
    write(io, vlr.record_id)
    record_data_length = vlr.extended ? UInt64(sizeof(vlr.data)) : UInt16(sizeof(vlr.data))
    write(io, record_data_length)
    writestring(io, vlr.description, 32)
    write(io, vlr.data)
    nothing
end

is_ogc_wkt_record(vlr::LasVariableLengthRecord) = (get_user_id(vlr) == "LASF_Projection") && (get_record_id(vlr) == ID_OGCWKTTAG)
is_classification_lookup_record(vlr::LasVariableLengthRecord) = (get_user_id(vlr) == LAS_SPEC_USER_ID) && (get_record_id(vlr) == ID_CLASSLOOKUP)

"Test whether a vlr is a GeoKeyDirectoryTag, GeoDoubleParamsTag or GeoAsciiParamsTag"
is_srs(vlr::LasVariableLengthRecord) = vlr.record_id in (
    ID_GEOKEYDIRECTORYTAG,
    ID_GEODOUBLEPARAMSTAG,
    ID_GEOASCIIPARAMSTAG)

"""
    $(TYPEDSIGNATURES)

Extract all VLRs with a `user_id` and `record_id` from a collection of VLRs, `vlrs`
"""
function extract_vlr_type(vlrs::Vector{<:LasVariableLengthRecord}, user_id::String, record_id::Integer)
    matches_ids = findall(vlr -> (get_user_id(vlr) == user_id) && (get_record_id(vlr) == record_id), vlrs)
    return vlrs[matches_ids]
end