"""
    $(TYPEDEF)

A LAS Header containing metadata regarding information in a LAS file
See full specification [here](https://www.asprs.org/wp-content/uploads/2019/03/LAS_1_4_r14.pdf#subsection.0.2.4)

$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct LasHeader
    """The LAS spec version this header was written in"""
    las_version::VersionNumber = v"1.4"

    """Numeric identifier for the source that made this file. Set to 0 if the ID is unassigned"""
    file_source_id::UInt16 = UInt16(0)

    """A bit field used to indicate global properties. See the spec for more info"""
    global_encoding::UInt16 = 0x0004

    """First member of the Project GUID"""
    guid_1::UInt32 = UInt32(0)

    """Second member of the Project GUID"""
    guid_2::UInt16 = UInt16(0)

    """Third member of the Project GUID"""
    guid_3::UInt16 = UInt16(0)

    """Fourth member of the Project GUID"""
    guid_4::NTuple{8, UInt8} = ntuple(_ -> UInt8(0), 8)
    
    """A unique identifier indicating how the data was created"""
    system_id::NTuple{32, UInt8} = Tuple(Vector{UInt8}("OTHER" * "\0"^27))

    """Identifier for the software that created the LAS file"""
    software_id::NTuple{32, UInt8} = Tuple(Vector{UInt8}(software_version() * "\0"^(max(0, 32 - length(software_version())))))

    """The Greenwich Mean Time (GMT) day of the year (as an unsigned short) on which the file was created"""
    creation_dayofyear::UInt16 =  UInt16((today() - Date(year(today()))).value)

    """Four digit number for the year the file was created"""
    creation_year::UInt16 = UInt16(year(today()))

    """Size (in bytes) of the public header block in the LAS file. This varies depending on which LAS version was used to write it. For LAS v1.4 it's 375 bytes"""
    header_size::UInt16 = UInt16(get_header_size_from_version(las_version))

    """Offset to the point data (in bytes) from the start of the file to the first field of the first point record"""
    data_offset::UInt32 = UInt32(375)

    """Number of Variable Length Records (VLR's) in the LAS file. These come after the header and before the point records"""
    n_vlr::UInt32 = UInt32(0)

    """Point data record format stored in the LAS file. LAS v1.4 supports formats 0-10"""
    data_format_id::UInt8 = UInt8(0)

    """Size in bytes of a point data record"""
    data_record_length::UInt16 = UInt16(0)

    """For maintaining legacy compatibility, the number of point records in the file (must not exceed `typemax(UInt32)`). Only populated for point records 0-5"""
    legacy_record_count::UInt32 = UInt32(0)

    """For maintaining legacy compatibility, the number of points per return (max of 5 returns, counts must not exceed `typemax(UInt32)`). Only populated for point records 0-5"""
    legacy_point_return_count::NTuple{5, UInt32} = ntuple(_ -> UInt32(0), 5)
    
    """Spatial information describing the bounding range of the points, their offsets and any scaling factor applied to them"""
    spatial_info::SpatialInfo = DEFAULT_SPATIAL_INFO
    
    """Offset in bytes from the start of the file to the first byte of the Waveform Data Package Reckord"""
    waveform_record_start::UInt64 = UInt64(0)

    """Offset in bytes from the start of the file to the first byte of the first Extended Variable Length Record (EVLR)"""
    evlr_start::UInt64 = UInt64(0)

    """Number of EVLR's in the LAS file"""
    n_evlr::UInt32 = UInt32(0)

    """Number of point records saved in this file (can't exceed `typemax(UInt64)`). This is populated for LAS v1.4"""
    record_count::UInt64 = UInt64(0)

    """Number of points per return saved in this file (15 returns total, counts can't exceed `typemax(UInt64)`). This is populated for LAS v1.4"""
    point_return_count::NTuple{15, UInt64} = ntuple(_ -> UInt64(0), 15)

    function LasHeader(las_version::VersionNumber,
        file_source_id::UInt16,
        global_encoding::UInt16,
        guid_1::UInt32,
        guid_2::UInt16,
        guid_3::UInt16,
        guid_4::NTuple{8, UInt8},
        system_id::NTuple{32, UInt8},
        software_id::NTuple{32, UInt8},
        creation_dayofyear::UInt16,
        creation_year::UInt16,
        header_size::UInt16,
        data_offset::UInt32,
        n_vlr::UInt32,
        data_format_id::UInt8,
        data_record_length::UInt16,
        legacy_record_count::UInt32,
        legacy_point_return_count::NTuple{5, UInt32},
        spatial_info::SpatialInfo,
        waveform_record_start::UInt64,
        evlr_start::UInt64,
        n_evlr::UInt32,
        record_count::UInt64,
        point_return_count::NTuple{15, UInt64})

        # restrict what LAS version types we support
        @assert (las_version.major == 1) && (las_version.minor ≤ 4) "Only LAS v1.1-1.4 supported!"
        
        # make sure header sizes are consistent with the relevant specs
        if las_version.minor ≤ 2
            @assert header_size == 227 "Invalid header size $(header_size). Must be 227 Bytes for LAS V1.1-1.2"
        elseif las_version.minor == 3
            @assert header_size == 235 "Invalid header size $(header_size). Must be 235 Bytes for LAS V1.3"
        elseif las_version.minor == 4
            @assert header_size == 375 "Invalid header size $(header_size). Must be 375 Bytes for LAS V1.3"
        end

        # make sure we have compatible point versions
        if (las_version.minor == 1 && data_format_id > 1)
            error("LasPoints 2 and higher not supported in LAS 1.1")
        elseif (las_version.minor == 2 && data_format_id > 3)
            error("LasPoints 4 and higher not supported in LAS 1.2")
        elseif (las_version.minor == 3 && data_format_id > 5)
            error("LasPoints 6 and higher not supported in LAS 1.3")
        elseif (las_version.minor == 4 && data_format_id > 10)
            error("LasPoints 11 and higher not supported in LAS 1.4")
        end

        return new(las_version, 
                    file_source_id, 
                    global_encoding,
                    guid_1,
                    guid_2,
                    guid_3,
                    guid_4,
                    system_id,
                    software_id,
                    creation_dayofyear,
                    creation_year,
                    header_size,
                    data_offset,
                    n_vlr,
                    data_format_id,
                    data_record_length,
                    legacy_record_count,
                    legacy_point_return_count,
                    spatial_info,
                    waveform_record_start,
                    evlr_start,
                    n_evlr,
                    record_count,
                    point_return_count
                )        
    end
end

function Base.:(==)(h1::LasHeader, h2::LasHeader)
    return all(map(property -> getproperty(h1, property) == getproperty(h2, property), fieldnames(LasHeader)))
end

function Base.show(io::IO, header::LasHeader)
    n = number_of_points(header)
    println(io, "LasHeader v$(header.las_version.major).$(header.las_version.minor) with $n points.")
    println(io, string("\tfile_source_id = ", header.file_source_id))
    println(io, string("\tglobal_encoding = ", bitstring(header.global_encoding)))
    println(io, string("\tguid_1 = ", header.guid_1))
    println(io, string("\tguid_2 = ", header.guid_2))
    println(io, string("\tguid_3 = ", header.guid_3))
    println(io, string("\tguid_4 = ", String(collect(header.guid_4))))
    println(io, string("\tsystem_id = ", system_id(header)))
    println(io, string("\tsoftware_id = ", software_id(header)))
    println(io, string("\tcreation_dayofyear = ", header.creation_dayofyear))
    println(io, string("\tcreation_year = ", header.creation_year))
    println(io, string("\theader_size = ", header.header_size))
    println(io, string("\tdata_offset = ", header.data_offset))
    println(io, string("\tn_vlr = ", header.n_vlr))
    println(io, string("\tdata_format_id = ", header.data_format_id))
    println(io, string("\tdata_record_length = ", header.data_record_length))
    if header.las_version <= v"1.3"
        println(io, string("\trecord_count = ", header.legacy_record_count))
        println(io, string("\tpoint_return_count = ", Int.(header.legacy_point_return_count))) 
    end
    println(io, string("\tx_scale = ", header.spatial_info.scale.x))
    println(io, string("\ty_scale = ", header.spatial_info.scale.y))
    println(io, string("\tz_scale = ", header.spatial_info.scale.z))
    println(io, string("\tx_offset = ", header.spatial_info.offset.x))
    println(io, string("\ty_offset = ", header.spatial_info.offset.y))
    println(io, string("\tz_offset = ", header.spatial_info.offset.z))
    println(io, @sprintf "\tx_max = %.7f" header.spatial_info.range.x.max)
    println(io, @sprintf "\tx_min = %.7f" header.spatial_info.range.x.min)
    println(io, @sprintf "\ty_max = %.7f" header.spatial_info.range.y.max)
    println(io, @sprintf "\ty_min = %.7f" header.spatial_info.range.y.min)
    println(io, @sprintf "\tz_max = %.7f" header.spatial_info.range.z.max)
    println(io, @sprintf "\tz_min = %.7f" header.spatial_info.range.z.min)
    if header.las_version ≥ v"1.3"
        println(io, string("\twaveform_record_start = ", header.waveform_record_start))
    end
    if header.las_version ≥ v"1.4"
        println(io, string("\tevlr_start = ", header.evlr_start))
        println(io, string("\tn_evlr = ", header.n_evlr))
        println(io, string("\trecord_count = ", header.record_count))
        println(io, string("\tpoint_return_count = ", Int.(header.point_return_count)))
    end
end

"""
    $(TYPEDSIGNATURES)

Get the header size (in bytes) for a given LAS version (as found in each version's spec)
"""
function get_header_size_from_version(las_version::VersionNumber)
    if las_version.minor ≤ 2
        return 227
    elseif las_version.minor == 3
        return 235
    elseif las_version.minor == 4
        return 375
    else
        error("Unsupported LAS version $(las_version): must be ≤ v1.4")
    end
end

function Base.read(io::IO, ::Type{LasHeader})
    @assert skiplasf(io) == "LASF" "Unrecognised file signature!"
    
    file_source_id = read(io, UInt16)
    global_encoding = read(io, UInt16)
    
    guid_1 = read(io, UInt32)
    guid_2 = read(io, UInt16)
    guid_3 = read(io, UInt16)
    guid_4 =  Tuple(read(io, 8))
    
    version_major = read(io, UInt8)
    version_minor = read(io, UInt8)
    las_version = VersionNumber(version_major, version_minor)
    
    is_at_least_v14 = las_version ≥ v"1.4"
    
    system_id = Tuple(read(io, 32))
    software_id = Tuple(read(io, 32))
    
    creation_dayofyear = read(io, UInt16)
    creation_year = read(io, UInt16)
    
    header_size = read(io, UInt16)
    data_offset = read(io, UInt32)
    n_vlr = read(io, UInt32)
    
    data_format_id = read(io, UInt8)
    data_record_length = read(io, UInt16)

    legacy_record_count, legacy_point_return_count, spatial_info, waveform_record_start, evlr_start, num_evlr, record_count, point_return_count = read_final_fields(io, las_version, is_at_least_v14)

    # put it all in a type
    return LasHeader(
        las_version,
        file_source_id,
        global_encoding,
        guid_1,
        guid_2,
        guid_3,
        guid_4,
        system_id,
        software_id,
        creation_dayofyear,
        creation_year,
        header_size,
        data_offset,
        n_vlr,
        data_format_id,
        data_record_length,
        legacy_record_count,
        legacy_point_return_count,
        spatial_info,
        waveform_record_start,
        evlr_start,
        num_evlr,
        record_count,
        point_return_count
    )
end

"""
    $(TYPEDSIGNATURES)

Helper function that reads the last few fields (from legacy record count to point return count) of a LAS header from an `io`
"""
function read_final_fields(io::IO, las_version::VersionNumber, is_at_least_v14::Bool)
    legacy_record_count = read(io, UInt32)
    legacy_point_return_count = Tuple(read!(io, Vector{UInt32}(undef, 5)))
    
    spatial_info = SpatialInfo(AxisInfo(POINT_SCALE, POINT_SCALE, POINT_SCALE), AxisInfo(0.0, 0.0, 0.0), AxisInfo(Range(Inf, -Inf), Range(Inf, -Inf), Range(Inf, -Inf)))
    evlr_start = zero(UInt64)
    num_evlr = zero(UInt32)
    record_count = zero(UInt64)
    point_return_count = Tuple(zeros(UInt64, 15))

    spatial_info = read(io, SpatialInfo)

    # start of waveform data record (unsupported)
    waveform_record_start = las_version >= v"1.3" ? read(io, UInt64) : zero(UInt64)

    if is_at_least_v14
        evlr_start = read(io, UInt64)
        num_evlr = read(io, UInt32)
        record_count = read(io, UInt64)
        point_return_count = Tuple(read!(io, Vector{UInt64}(undef, 15)))
    end

    return legacy_record_count, legacy_point_return_count, spatial_info, waveform_record_start, evlr_start, num_evlr, record_count, point_return_count
end

function Base.write(io::IO, h::LasHeader)
    writestring(io, "LASF", 4)
    write(io, h.file_source_id)
    write(io, h.global_encoding)
    write(io, h.guid_1)
    write(io, h.guid_2)
    write(io, h.guid_3)
    write(io, collect(h.guid_4))
    write(io, UInt8(h.las_version.major))
    write(io, UInt8(h.las_version.minor))
    write(io, collect(h.system_id))
    write(io, collect(h.software_id))
    write(io, h.creation_dayofyear)
    write(io, h.creation_year)
    write(io, h.header_size)
    write(io, h.data_offset)
    write(io, h.n_vlr)
    write(io, h.data_format_id)
    write(io, h.data_record_length)
    write(io, h.legacy_record_count)
    write(io, collect(h.legacy_point_return_count))
    write(io, h.spatial_info.scale.x)
    write(io, h.spatial_info.scale.y)
    write(io, h.spatial_info.scale.z)
    write(io, h.spatial_info.offset.x)
    write(io, h.spatial_info.offset.y)
    write(io, h.spatial_info.offset.z)
    write(io, h.spatial_info.range.x.max)
    write(io, h.spatial_info.range.x.min)
    write(io, h.spatial_info.range.y.max)
    write(io, h.spatial_info.range.y.min)
    write(io, h.spatial_info.range.z.max)
    write(io, h.spatial_info.range.z.min)

    if las_version(h) ≥ v"1.3"
        write(io, h.waveform_record_start)
    end

    if las_version(h) ≥ v"1.4"
        write(io, h.evlr_start)
        write(io, h.n_evlr)
        write(io, h.record_count)
        write(io, collect(h.point_return_count))
    end
    nothing
end

"""
    $(TYPEDSIGNATURES)

Get the LAS specification version from a header `h`
"""
las_version(h::LasHeader) = h.las_version

"""
    $(TYPEDSIGNATURES)

Get the file source ID specification version from a header `h`
"""
file_source_id(h::LasHeader) = h.file_source_id

"""
    $(TYPEDSIGNATURES)

Get the global properties bit vector from a header `h`
"""
global_encoding(h::LasHeader) = h.global_encoding

"""
    $(TYPEDSIGNATURES)

Get the system ID from a header `h`
"""
system_id(h::LasHeader) = replace(String(collect(h.system_id)), "\0" => "")

"""
    $(TYPEDSIGNATURES)

Get the software ID from a header `h`
"""
software_id(h::LasHeader) = replace(String(collect(h.software_id)), "\0" => "")

"""
    $(TYPEDSIGNATURES)

Get the creation day of the year from a header `h`
"""
creation_day_of_year(h::LasHeader) = h.creation_dayofyear

"""
    $(TYPEDSIGNATURES)

Get the creation year from a header `h`
"""
creation_year(h::LasHeader) = h.creation_year

"""
    $(TYPEDSIGNATURES)

Get the size of a header `h` in bytes
"""
header_size(h::LasHeader) = Int(h.header_size)

"""
    $(TYPEDSIGNATURES)

Get the offset to the first point record in a LAS file specified by a header `h`
"""
point_data_offset(h::LasHeader) = Int(h.data_offset)

"""
    $(TYPEDSIGNATURES)

Get the number of bytes assigned to each point record in a LAS file specified by a header `h`
"""
point_record_length(h::LasHeader) = Int(h.data_record_length)

"""
    $(TYPEDSIGNATURES)

Get the LAS point format from a header `header`
"""
function point_format(header::LasHeader)
    return get_point_format(LasPoint{Int(header.data_format_id)})
end

"""
    $(TYPEDSIGNATURES)

Get the number of points in a LAS file from a header `h`
"""
number_of_points(h::LasHeader) = h.las_version ≥ v"1.4" ? Int(h.record_count) : Int(h.legacy_record_count)

"""
    $(TYPEDSIGNATURES)

Get the number of Variable Length Records in a LAS file from a header `h`
"""
number_of_vlrs(h::LasHeader) = Int(h.n_vlr)

"""
    $(TYPEDSIGNATURES)

Get the number of Extended Variable Length Records in a LAS file from a header `h`
"""
number_of_evlrs(h::LasHeader) = Int(h.n_evlr)

"""
    $(TYPEDSIGNATURES)

Get the offset in bytes to the first EVLR in a LAS file from a header `header`
"""
evlr_start(header::LasHeader) = header.evlr_start

"""
    $(TYPEDSIGNATURES)

Get the spatial information for point positions in a LAS file from a header `h`. This includes the offsets/scale factors applied to points and bounding box information
"""
spatial_info(h::LasHeader) = h.spatial_info

"""
    $(TYPEDSIGNATURES)

Get the scale for point positions in a LAS file from a header `h`. Checks consistent scale for ALL axes.
"""
function scale(h::LasHeader) 

    @assert (h.spatial_info.scale.x == h.spatial_info.scale.y) && (h.spatial_info.scale.y == h.spatial_info.scale.z) "We expect all axes to be scaled similarly"
    
    return h.spatial_info.scale.x
end

"""
    $(TYPEDSIGNATURES)

Get the number of return channels in a LAS file from a header `h`
"""
num_return_channels(h::LasHeader) = las_version(h) ≥ v"1.4" ? 15 : 5

"""
    $(TYPEDSIGNATURES)

Set the LAS specification version in a header `h` to version `v`
"""
function set_las_version!(h::LasHeader, v::VersionNumber)
    _point_format_version_consistent(v, point_format(h))
    old_version = deepcopy(las_version(h))
    h.las_version = v
    h.header_size = get_header_size_from_version(v)
    h.data_offset += (h.header_size - get_header_size_from_version(old_version))
    set_point_record_count!(h, number_of_points(h))
    set_number_of_points_by_return!(h, get_number_of_points_by_return(h))
    return nothing
end

function _point_format_version_consistent(v::VersionNumber, ::Type{TPoint}) where {TPoint <: LasPoint}
    point_format_id = get_point_format_id(TPoint)
    if any([
        (v ≤ v"1.1") && (point_format_id ≥ 2),
        (v ≤ v"1.2") && (point_format_id ≥ 4),
        (v ≤ v"1.3") && (point_format_id ≥ 5),
        (v ≤ v"1.4") && (point_format_id ≥ 11),
        v ≥ v"1.5"
    ])
        error("Incompatible LAS version $(v) with point format $(point_format_id)")
    end
end

"""
    $(TYPEDSIGNATURES)

Set the point format in a header `h` to a new value, `TPoint`
"""
function set_point_format!(h::LasHeader, ::Type{TPoint}) where {TPoint <: LasPoint}
    v = las_version(h)
    minimal_required_version = lasversion_for_point(TPoint)
    old_format = point_format(h)
    old_format_id = get_point_format_id(old_format)
    # make sure that the LAS version in the header is consistent with the point format we want - upgrade if necessary, but let the user know
    if v < minimal_required_version
        @warn "Updating LAS version from $(v) to $(minimal_required_version) to accomodate changing point format from $(old_format) to $(TPoint)"
        set_las_version!(h, minimal_required_version)
    end
    _point_format_version_consistent(las_version(h), TPoint)
    h.data_format_id = get_point_format_id(TPoint)
    h.data_record_length += (byte_size(TPoint) - byte_size(LasPoint{Int(old_format_id)}))
    set_point_record_count!(h, number_of_points(h))
    set_number_of_points_by_return!(h, get_number_of_points_by_return(h))
    return nothing
end

"""
    $(TYPEDSIGNATURES)

Set the spatial information associated to points in a LAS file with a header `header`
"""
function set_spatial_info!(header::LasHeader, info::SpatialInfo)
    header.spatial_info = info
end

"""
    $(TYPEDSIGNATURES)

Set offset to the first point record in a LAS file with a header `header`
"""
function set_point_data_offset!(header::LasHeader, offset::Integer)
    header.data_offset = UInt32(offset)
end

function set_point_format!(header::LasHeader, id::Integer)
    header.data_format_id = UInt8(id)
end

"""
    $(TYPEDSIGNATURES)

Set the number of bytes associated to each point record in a LAS file with a header `header`
"""
function set_point_record_length!(header::LasHeader, length::Integer)
    header.data_record_length = UInt16(length)
end

"""
    $(TYPEDSIGNATURES)

Set the number of points in a LAS file with a header `header`
"""
function set_point_record_count!(header::LasHeader, num_points::Integer)
    if (las_version(header) == v"1.4")
        @assert num_points ≤ typemax(UInt64) "Can't have more than $(typemax(UInt64)) points for LAS v1.4"
    else
        @assert num_points ≤ typemax(UInt32) "Can't have more than $(typemax(UInt32)) points for LAS v1.0-1.3"
    end
    header.record_count = UInt64(num_points)
    if get_point_format_id(point_format(header)) ≤ 5
        header.legacy_record_count = UInt32(num_points)
    end
    return nothing
end

"""
    $(TYPEDSIGNATURES)

Set the number of Variable Length Records in a LAS file with a header `header`
"""
function set_num_vlr!(header::LasHeader, n::Integer)
    header.n_vlr = UInt64(n)
end

"""
    $(TYPEDSIGNATURES)

Set the number of Extended Variable Length Records in a LAS file with a header `header`
"""
function set_num_evlr!(header::LasHeader, n::Integer)
    @assert las_version(header) == v"1.4" "Can't have extended variable length records in LAS version $(las_version(header))"
    header.n_evlr = UInt64(n)
end

"""If true, GPS Time is standard GPS Time (satellite GPS Time) minus 1e9.
If false, GPS Time is GPS Week Time.

Note that not all software sets this encoding correctly."""
is_standard_gps(h::LasHeader) = isodd(h.global_encoding)

"Check if the projection information is in WKT format (true) or GeoTIFF (false)"
function is_wkt(h::LasHeader)
    wkit_bit = Bool((h.global_encoding & 0x0010) >> 4)
    if !wkit_bit && h.data_format_id > 5
        throw(DomainError("WKT bit must be true for point types higher than 5"))
    end
    wkit_bit
end

"""
    $(TYPEDSIGNATURES)

Sets the bit flag indicating that the header `header` is in GPS week time
"""
function set_gps_week_time_bit!(header::LasHeader)
    # setting bit 0 to 0
    header.global_encoding &= 0xfffe
end

"""
    $(TYPEDSIGNATURES)

Sets the bit flag indicating that the header `header` is in GPS standard time
"""
function set_gps_standard_time_bit!(header::LasHeader)
    # setting bit 0 to 1
    header.global_encoding |= 0x0001
end

"""
    $(TYPEDSIGNATURES)

Returns whether a LAS file with header `header` has waveform data stored in the LAS file
"""
function is_internal_waveform(header::LasHeader)
    return Bool((header.global_encoding & 0x0002) >> 1)
end

"""
    $(TYPEDSIGNATURES)

Returns whether a LAS file with header `header` has waveform data in an external file
"""
function is_external_waveform(header::LasHeader)
    return Bool((header.global_encoding & 0x0004) >> 2)
end

"""
    $(TYPEDSIGNATURES)

Sets the bit flag indicating that the header `header` has internal waveform records
"""
function set_waveform_internal_bit!(header::LasHeader)
    # setting bit 1 to 1 and bit 2 to 0
    header.global_encoding |= 0x0002
    header.global_encoding &= 0xfffb
end

"""
    $(TYPEDSIGNATURES)

Sets the bit flag indicating that the header `header` has external waveform records
"""
function set_waveform_external_bit!(header::LasHeader)
    # setting bit 2 to 1 and bit 1 to 0
    header.global_encoding |= 0x0004
    header.global_encoding &= 0xfffd
end

"""
    $(TYPEDSIGNATURES)

Unset all bit flags in a `header` to do with waveform information
"""
function unset_waveform_bits!(header::LasHeader)
    # setting bits 2 and 1 to 0
    header.global_encoding &= 0xfff9
end

"""
    $(TYPEDSIGNATURES)

Sets the bit flag indicating that the header `header` has synthetically-generated return numbers
"""
function set_synthetic_return_numbers_bit!(header::LasHeader)
    # setting bit 3 to 1
    header.global_encoding |= 0x0008
end

"""
    $(TYPEDSIGNATURES)

Sets the bit flag indicating that the header `header` does not have synthetically-generated return numbers
"""
function unset_synthetic_return_numbers_bit!(header::LasHeader)
    # setting bit 3 to 0
    header.global_encoding &= 0xfff7
end

"""
    $(TYPEDSIGNATURES)

Sets the bit flag indicating that the LAS file with header `header` has its coordinate reference system set as a WKT 
"""
function set_wkt_bit!(header::LasHeader)
    # need to set bit 4 to 1
    header.global_encoding |= 0x0010
end

"""
    $(TYPEDSIGNATURES)

Sets the bit flag indicating that the LAS file with header `header` doesn't have its coordinate reference system set as a WKT 
"""
function unset_wkt_bit!(header::LasHeader)
    # need to set bit 4 to 0
    header.global_encoding &= 0xffef
end

"""
    $(TYPEDSIGNATURES)

Get the number of points per return for a header `header`
"""
function get_number_of_points_by_return(header::LasHeader)
    return las_version(header) ≥ v"1.4" ? header.point_return_count : header.legacy_point_return_count
end

"""
    $(TYPEDSIGNATURES)

Set the number of points per return for a header `header` to the values `points_per_return`
"""
function set_number_of_points_by_return!(header::LasHeader, points_per_return::NTuple{N, Integer}) where N
    return_limit = las_version(header) ≥ v"1.4" ? typemax(UInt64) : typemax(UInt32)
    @assert all(points_per_return .≤ return_limit) "Maximum allowed points per return count is $return_limit"
    @assert N == num_return_channels(header) "Number of returns $N doesn't match what's in header $(num_return_channels(header))"
    # note - internally, we store the point return count up to 15 places, even if the version spec only needs 5 - saves having to redefine field types for header
    header.point_return_count = ntuple(i -> i ≤ N ? points_per_return[i] : 0, 15)
    if get_point_format_id(point_format(header)) ≤ 5
        header.legacy_point_return_count = ntuple(i -> i ≤ N ? points_per_return[i] : 0, 5)
    else
        header.legacy_point_return_count = (0, 0, 0, 0, 0)
    end
end

"""
    $(TYPEDSIGNATURES)

Get the offset in bytes to the first waveform record for a LAS file with header `header`
"""
waveform_record_start(header::LasHeader) = header.waveform_record_start

"X coordinate (Float64), apply scale and offset according to the header"
xcoord(p::LasPoint, h::LasHeader) = xcoord(p, spatial_info(h))
"Y coordinate (Float64), apply scale and offset according to the header"
ycoord(p::LasPoint, h::LasHeader) = ycoord(p, spatial_info(h))
"Z coordinate (Float64), apply scale and offset according to the header"
zcoord(p::LasPoint, h::LasHeader) = zcoord(p, spatial_info(h))

xcoord(p::LasPoint, xyz::SpatialInfo) = p.x * xyz.scale.x + xyz.offset.x
ycoord(p::LasPoint, xyz::SpatialInfo) = p.y * xyz.scale.y + xyz.offset.y
zcoord(p::LasPoint, xyz::SpatialInfo) = p.z * xyz.scale.z + xyz.offset.z

# inverse functions of the above
"X value (Int32), as represented in the point data, reversing the offset and scale from the header"
xcoord(x::Real, h::LasHeader) = xcoord(x, spatial_info(h))
"Y value (Int32), as represented in the point data, reversing the offset and scale from the header"
ycoord(y::Real, h::LasHeader) = ycoord(y, spatial_info(h))
"Z value (Int32), as represented in the point data, reversing the offset and scale from the header"
zcoord(z::Real, h::LasHeader) = zcoord(z, spatial_info(h))

xcoord(x::Real, xyz::SpatialInfo) = get_int(Int32, x, xyz.offset.x, xyz.scale.x)
ycoord(y::Real, xyz::SpatialInfo) = get_int(Int32, y, xyz.offset.y, xyz.scale.y)
zcoord(z::Real, xyz::SpatialInfo) = get_int(Int32, z, xyz.offset.z, xyz.scale.z)

"""
    $(TYPEDSIGNATURES)

Construct a LAS header that is consistent with a given `pointcloud` data in a specific LAS `point_format`, coupled with sets of `vlrs`, `evlrs` and `user_defined_bytes` 
"""
function make_consistent_header(pointcloud::AbstractVector{<:NamedTuple}, 
                                point_format::Type{TPoint},
                                vlrs::Vector{<:LasVariableLengthRecord}, 
                                evlrs::Vector{<:LasVariableLengthRecord},
                                user_defined_bytes::Vector{UInt8},
                                scale::Real) where {TPoint <: LasPoint}
    version = lasversion_for_point(point_format)

    spatial_info = get_spatial_info(pointcloud; scale = scale)

    header = LasHeader(; 
        las_version = version, 
        data_format_id = UInt8(get_point_format_id(point_format)),
        data_record_length = UInt16(byte_size(point_format)),
        spatial_info = spatial_info,
    )

    make_consistent_header!(header, pointcloud, vlrs, evlrs, user_defined_bytes)
    
    return header
end

"""
    $(TYPEDSIGNATURES)

Ensure that a LAS `header` is consistent with a given `pointcloud` data coupled with sets of `vlrs`, `evlrs` and `user_defined_bytes`
"""
function make_consistent_header!(header::LasHeader, 
                                pointcloud::AbstractVector{<:NamedTuple},
                                vlrs::Vector{<:LasVariableLengthRecord}, 
                                evlrs::Vector{<:LasVariableLengthRecord},
                                user_defined_bytes::Vector{UInt8})
    header_size = get_header_size_from_version(las_version(header))
    vlr_size = isempty(vlrs) ? 0 : sum(sizeof.(vlrs))
    point_data_offset = header_size + vlr_size + length(user_defined_bytes)
    
    set_point_data_offset!(header, point_data_offset)
    
    _consolidate_point_header_info!(header, pointcloud)

    if !isempty(vlrs)
        set_num_vlr!(header, length(vlrs))
    end
    if !isempty(evlrs)
        set_num_evlr!(header, length(evlrs))
    end

    ogc_wkt_records = is_ogc_wkt_record.(vlrs)
    @assert count(ogc_wkt_records) ≤ 1 "Can't set more than 1 OGC WKT Transform in VLR's!"

    this_format = point_format(header)
    if (get_point_format_id(this_format) ≥ 6) || any(ogc_wkt_records)
        set_wkt_bit!(header)
    end

    if this_format <: LasPointWavePacket
        # only setting the external waveform bit since the internal one is deprecated
        set_waveform_external_bit!(header)
    else
        # don't want waveform bits set for point formats that don't have waveform data
        unset_waveform_bits!(header)
    end

    return nothing
end

function _consolidate_point_header_info!(header::LasHeader, pointcloud::AbstractVector{<:NamedTuple})
    set_spatial_info!(header, get_spatial_info(pointcloud; scale = scale(header)))
    
    set_point_record_count!(header, length(pointcloud))
    returns = (:returnnumber ∈ columnnames(pointcloud)) ? pointcloud.returnnumber : ones(Int, length(pointcloud))
    points_per_return = ntuple(r -> count(returns .== r), num_return_channels(header))
    set_number_of_points_by_return!(header, points_per_return)
    return nothing
end