"""
    $(TYPEDEF)

A lookup record for classification labels. Each class has a short description telling you what it is.

$(TYPEDFIELDS)
---

$(METHODLIST)
"""
struct ClassificationLookup
    """Mapping of each class to a description"""
    class_description_map::Dict{UInt8, String}
    function ClassificationLookup(class_description_map::Dict{TInt, String}) where {TInt <: Integer}
        @assert all(keys(class_description_map) .≤ typemax(UInt8)) "Classes must be between 0 and 255"
        @assert all(sizeof.(values(class_description_map)) .≤ 15) "Class descriptions must be at most 15 bytes"
    
        return new(Dict(UInt8(class) => class_description_map[class] for class ∈ keys(class_description_map)))
    end
end

function ClassificationLookup(class_descriptions::Vararg{TPair, N}) where {TInt <: Integer, TPair <: Pair{TInt, String}, N}
    ClassificationLookup(Dict(class_descriptions))
end

get_description(lookup::ClassificationLookup, class::Integer) = lookup.class_description_map[UInt8(class)]
get_classes(lookup::ClassificationLookup) = sort(collect(keys(lookup.class_description_map)))
Base.length(lookup::ClassificationLookup) = length(lookup.class_description_map)
Base.sizeof(lookup::ClassificationLookup) = 16 * Base.length(lookup)
Base.:(==)(l1::ClassificationLookup, l2::ClassificationLookup) = l1.class_description_map == l2.class_description_map

function set_description!(lookup::ClassificationLookup, class::Integer, description::String)
    @assert sizeof(description) ≤ 15 "Desciption must be at most 15 bytes"
    lookup.class_description_map[UInt8(class)] = description
end

@register_vlr_type ClassificationLookup LAS_SPEC_USER_ID ID_CLASSLOOKUP

function read_vlr_data(io::IO, ::Type{ClassificationLookup}, nb::Integer)
    @assert nb % 16 == 0 "Number of bytes to read for ClassificationLookup must be multiple of 16. Got $(nb)"
    class_description_map = Dict{UInt8, String}()
    num_classes = nb / 16
    for _ ∈ 1:num_classes
        class = read(io, UInt8)
        description = readstring(io, 15)
        class_description_map[class] = description
    end
    return ClassificationLookup(class_description_map)
end

function Base.write(io::IO, lookup::ClassificationLookup)
    for class ∈ get_classes(lookup)
        write(io, class)
        writestring(io, get_description(lookup, class), 15)
    end
end

"""
    $(TYPEDEF)

A wrapper around a text area description, which is used for providing a textual description of the content of the LAS file

$(TYPEDFIELDS)
"""
struct TextAreaDescription
    """Text describing the content of the LAS file"""
    txt::String
end

@register_vlr_type TextAreaDescription LAS_SPEC_USER_ID ID_TEXTDESCRIPTION
Base.write(io::IO, desc::TextAreaDescription) = write(io, desc.txt)
read_vlr_data(io::IO, ::Type{TextAreaDescription}, nb::Integer) = TextAreaDescription(readstring(io, nb))
Base.sizeof(desc::TextAreaDescription) = Base.sizeof(desc.txt)

"""
    $(TYPEDEF)

Extra Bytes record that documents an extra field present for a point in a LAS file

$(TYPEDFIELDS)
"""
struct ExtraBytes{TData}
    """Specifies whether the min/max range, scale factor and offset for this field is set/meaningful and whether there is a special value to be interpreted as \"NO_DATA\""""
    options::UInt8

    """Name of the extra field"""
    name::String

    """A value that's used if the \"NO_DATA\" flag is set in `options`. Use this if the point doesn't have data for this type"""
    no_data::TData

    """Minimum value for this field, zero if not using"""
    min_val::TData

    """Maximum value for this field, zero if not using"""
    max_val::TData

    """Scale factor applied to this field, zero if not using"""
    scale::TData

    """Offset applied to this field, zero if not using"""
    offset::TData

    """Description of this extra field"""
    description::String

    function ExtraBytes{TData}(options::UInt8, name::String, no_data::TData, min_val::TData, max_val::TData, scale::TData, offset::TData, description::String) where TData
        @assert TData ∈ SUPPORTED_EXTRA_BYTES_TYPES "Extra Bytes records not supported for data type $TData"
        return new{TData}(options, name, no_data, min_val, max_val, scale, offset, description)
    end
end

function ExtraBytes(options::UInt8, name::String, no_data::TData, min_val::TData, max_val::TData, scale::TData, offset::TData, description::String) where TData
    return ExtraBytes{TData}(options, name, no_data, min_val, max_val, scale, offset, description)
end

Base.sizeof(::Type{ExtraBytes}) = 192
Base.sizeof(::ExtraBytes) = Base.sizeof(ExtraBytes)

@register_vlr_type ExtraBytes LAS_SPEC_USER_ID ID_EXTRABYTES

# we can rely on this indexing safely since we're restricted to TData being in SUPPORTED_EXTRA_BYTES_TYPES
data_code_from_type(::Type{TData}) where TData = (TData == Missing ? 0x00 : UInt8(indexin([TData], SUPPORTED_EXTRA_BYTES_TYPES)[1]))
data_code_from_type(::ExtraBytes{TData}) where TData = data_code_from_type(TData)

function data_type_from_code(code::Integer) 
    @assert 0 ≤ code ≤ length(SUPPORTED_EXTRA_BYTES_TYPES) "Unsupported data code! Must be between 0 and $(length(SUPPORTED_EXTRA_BYTES_TYPES))"
    code == 0 ? Missing : SUPPORTED_EXTRA_BYTES_TYPES[code]
end

"""
    $(TYPEDSIGNATURES)

Get the name of an additional user field that's documented by an extra bytes record `e`
"""
name(e::ExtraBytes) = e.name
"""
    $(TYPEDSIGNATURES)

Get the data type of an `ExtraBytes` record
"""
data_type(::ExtraBytes{TData}) where TData = TData
no_data_flag(e::ExtraBytes) = Bool(e.options & 0x01)
min_flag(e::ExtraBytes) = Bool(e.options & 0x02)
max_flag(e::ExtraBytes) = Bool(e.options & 0x04)
scale_flag(e::ExtraBytes) = Bool(e.options & 0x08)
offset_flag(e::ExtraBytes) = Bool(e.options & 0x10)

function get_extra_bytes_field(extra_bytes::SVector{N, T}) where {N, T <: ExtraBytes}
    if N == 0
        return missing
    else
        return NamedTuple{ntuple(i -> Symbol(get_name(extra_bytes[i])), N), ntuple(i -> data_type(extra_bytes[i]), N)}
    end
end

function Base.read(io::IO, ::Type{ExtraBytes})
    # ignore reserved
    read(io, UInt16)
    data_code = read(io, UInt8)
    
    # shouldn't be an "undocumented" Extra Bytes VLR on a read by definition
    @assert data_code != 0 "Extra Bytes VLR labelled as undocumented even though it's documented?"

    data_type = data_type_from_code(data_code)
    options = read(io, UInt8)
    name = readstring(io, 32)
    # ignore unused
    read(io, UInt32)
    no_data = reinterpret(data_type, read(io, 8))[1]
    # ignore deprecated1
    read(io, 16)
    min_value = reinterpret(data_type, read(io, 8))[1]
    # ignore deprecated2
    read(io, 16)
    max_value = reinterpret(data_type, read(io, 8))[1]
    # ignore deprecated3
    read(io, 16)
    scale = reinterpret(data_type, read(io, 8))[1]
    # ignore deprecated4
    read(io, 16)
    offset = reinterpret(data_type, read(io, 8))[1]
    # ignore deprecated5
    read(io, 16)
    description = readstring(io, 32)

    return ExtraBytes{data_type}(options, name, no_data, min_value, max_value, scale, offset, description)
end

function Base.write(io::IO, extra_bytes::ExtraBytes{TData}) where TData
    # reserved
    write(io, zero(UInt16))
    write(io, data_code_from_type(TData))
    write(io, extra_bytes.options)
    writestring(io, extra_bytes.name, 32)
    # unused
    write(io, zero(UInt32))
    write(io, upcast_to_8_byte(extra_bytes.no_data))
    # deprecated1
    write(io, zeros(UInt8, 16))
    # note: no_data, min, and max fields need to be upcast to 8-byte storage
    write(io, upcast_to_8_byte(extra_bytes.min_val))
    # deprecated2
    write(io, zeros(UInt8, 16))
    write(io, upcast_to_8_byte(extra_bytes.max_val))
    # deprecated3
    write(io, zeros(UInt8, 16))
    write(io, upcast_to_8_byte(extra_bytes.scale))
    # deprecated4
    write(io, zeros(UInt8, 16))
    write(io, upcast_to_8_byte(extra_bytes.offset))
    # deprecated5
    write(io, zeros(UInt8, 16))
    writestring(io, extra_bytes.description, 32)
end

"""
    $(TYPEDEF)

A Wave Packet Descriptor which contains information that describes the configuration of the waveform packets. Since
systems may be configured differently at different times throughout a job, the LAS file supports
255 Waveform Packet Descriptors

$(TYPEDFIELDS)
"""
struct WaveformPacketDescriptor
    """Number of bits per sample. 2 to 32 bits per sample are supported"""
    bits_per_sample::UInt8

    """Indicates the compression algorithm used for the waveform packets associated with
    this descriptor. A value of 0 indicates no compression. Zero is the only value currently supported"""
    compression_type::UInt8

    """Number of samples associated to this packet type. This always corresponds to the decompressed waveform packet"""
    num_samples::UInt32

    """The temporal sample spacing in picoseconds. Example values might be 500, 1000, 2000, and so
    on, representing digitizer frequencies of 2 GHz, 1 GHz, and 500 MHz respectively."""
    temporal_sample_spacing::UInt32

    """The digitizer gain used to convert the raw digitized value to an absolute digitizer
    voltage using the formula:
    𝑉𝑂𝐿𝑇𝑆 = 𝑂𝐹𝐹𝑆𝐸𝑇 + 𝐺𝐴𝐼𝑁 * 𝑅𝑎𝑤_𝑊𝑎𝑣𝑒𝑓𝑜𝑟𝑚_𝐴𝑚𝑝𝑙𝑖𝑡𝑢𝑑𝑒
    """
    digitizer_gain::Float64

    """The digitizer offset used to convert the raw digitized value to an absolute digitizer using formula above"""
    digitizer_offset::Float64

    function WaveformPacketDescriptor(bits_per_sample::UInt8,
                                        compression_type::UInt8,
                                        num_samples::UInt32,
                                        temporal_sample_spacing::UInt32,
                                        digitizer_gain::Float64,
                                        digitizer_offset::Float64)
        @assert (bits_per_sample == 8) || (bits_per_sample == 16) "Only waveform packets with 8 or 16 bits per sample supported"
        return new(bits_per_sample, compression_type, num_samples, temporal_sample_spacing, digitizer_gain, digitizer_offset)
    end
end

@register_vlr_type(WaveformPacketDescriptor, LAS_SPEC_USER_ID, UInt16.(collect(100:354)))

function Base.read(io::IO, ::Type{WaveformPacketDescriptor})
    bits_per_sample = read(io, UInt8)
    compression_type = read(io, UInt8)
    num_samples = read(io, UInt32)
    temporal_sample_spacing = read(io, UInt32)
    digitizer_gain = read(io, Float64)
    digitizer_offset = read(io, Float64)
    return WaveformPacketDescriptor(bits_per_sample, compression_type, num_samples, temporal_sample_spacing, digitizer_gain, digitizer_offset)
end

function Base.write(io::IO, desc::WaveformPacketDescriptor)
    write(io, desc.bits_per_sample)
    write(io, desc.compression_type)
    write(io, desc.num_samples)
    write(io, desc.temporal_sample_spacing)
    write(io, desc.digitizer_gain)
    write(io, desc.digitizer_offset)
end

# TODO: Implement Waveform Data Record