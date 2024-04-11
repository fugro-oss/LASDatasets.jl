struct ClassificationLookup
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

@register_vlr_type(ClassificationLookup, LAS_SPEC_USER_ID, ID_CLASSLOOKUP)

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

@register_vlr_type(TextAreaDescription, LAS_SPEC_USER_ID, ID_TEXTDESCRIPTION)
read_vlr_data(io::IO, ::Type{TextAreaDescription}, nb::Integer) = TextAreaDescription(readstring(io, nb))

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
    𝑉 𝑂𝐿𝑇 𝑆 = 𝑂𝐹 𝐹 𝑆𝐸𝑇 + 𝐺𝐴𝐼𝑁 * 𝑅𝑎𝑤_𝑊 𝑎𝑣𝑒𝑓 𝑜𝑟𝑚_𝐴𝑚𝑝𝑙𝑖𝑡𝑢𝑑𝑒
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