Base.@kwdef mutable struct LazVariableLengthRecord
    reserved::UInt16 = UInt16(0)
    user_id::NTuple{16,UInt8} = ntuple(i -> UInt8(0x0), 16)
    record_id::UInt16 = UInt16(0)
    record_length_after_header::UInt16 = UInt16(0)
    description::NTuple{32,UInt8} = ntuple(i -> UInt8(0x0), 32)
    data::Ptr{UInt8} = pointer("")
end

Base.convert(::Type{LasVariableLengthRecord}, vlr::LazVariableLengthRecord) =
    LasVariableLengthRecord(
        vlr.reserved,
        join(convert(NTuple{16,Char}, vlr.user_id)),
        vlr.record_id,
        join(convert(NTuple{32,Char}, vlr.description)),
        unsafe_string(vlr.data, vlr.record_length_after_header)
    )

function string_as_byte_tuple(string::String, nb::Int)
    io = IOBuffer()
    writestring(io, string, nb)
    seek(io, 0)
    return Tuple(read(io, nb))
end

function get_data_pointer(data)
    io = IOBuffer()
    write(io, data)
    seek(io, 0)
    pointer(read(io))
end

Base.@kwdef mutable struct LazHeader
    file_source_ID::UInt16 = UInt16(0)
    global_encoding::UInt16 = UInt16(0)
    project_ID_GUID_data_1::UInt32 = UInt32(0)
    project_ID_GUID_data_2::UInt16 = UInt16(0)
    project_ID_GUID_data_3::UInt16 = UInt16(0)
    project_ID_GUID_data_4::NTuple{8,UInt8} = ntuple(i -> UInt8(20), 8)
    # project_ID_GUID_data_4::Array{UInt8, 1} = Array{UInt8, 1}(zeros(0, 8))
    version_major::UInt8 = UInt8(1)
    version_minor::UInt8 = UInt8(2)
    system_identifier::NTuple{32,UInt8} = ntuple(i -> UInt8(20), 32)
    # system_identifier::Array{UInt8} = Array{UInt8}(32)
    generating_software::NTuple{32,UInt8} = ntuple(i -> UInt8(20), 32)
    # generating_software::Array{UInt8, 1} = Array{UInt8, 1}(zeros(0, 32))
    file_creation_day::UInt16 = UInt16((today() - Date(year(today()))).value)
    file_creation_year::UInt16 = UInt16(year(today()))
    header_size::UInt16 = UInt16(227)
    offset_to_point_data::UInt32 = UInt32(227)
    number_of_variable_length_records::UInt32 = UInt32(0)
    point_data_format::UInt8 = UInt8(0)
    point_data_record_length::UInt16 = UInt16(20)
    number_of_point_records::UInt32 = UInt32(0)
    number_of_points_by_return::NTuple{5,UInt32} = ntuple(i -> UInt32(0), 5)
    # number_of_points_by_return::Array{UInt32, 1} = Array{UInt32, 1}(zeros(0, 5))
    x_scale_factor::Float64 = Float64(1.0)
    y_scale_factor::Float64 = Float64(1.0)
    z_scale_factor::Float64 = Float64(1.0)
    x_offset::Float64 = Float64(0.0)
    y_offset::Float64 = Float64(0.0)
    z_offset::Float64 = Float64(0.0)
    max_x::Float64 = Float64(0.0)
    min_x::Float64 = Float64(0.0)
    max_y::Float64 = Float64(0.0)
    min_y::Float64 = Float64(0.0)
    max_z::Float64 = Float64(0.0)
    min_z::Float64 = Float64(0.0)
    start_of_waveform_data_packet_record::UInt64 = UInt64(0)
    start_of_first_extended_variable_length_record::UInt64 = UInt64(0)
    number_of_extended_variable_length_records::UInt32 = UInt32(0)
    extended_number_of_point_records::UInt64 = UInt64(0)
    extended_number_of_points_by_return::NTuple{15,UInt64} = ntuple(i -> UInt64(0), 15)
    # extended_number_of_points_by_return::Array{UInt64, 1} = Array{UInt64, 1}(zeros(0, 15))
    user_data_in_header_size::UInt32 = UInt32(0)
    user_data_in_header::Ptr{UInt8} = pointer("")
    vlrs::Ptr{LazVariableLengthRecord} = pointer("")
    user_data_after_header_size::UInt32 = UInt32(0)
    user_data_after_header::Ptr{UInt8} = pointer("")
end

function Base.convert(::Type{LazHeader}, h::LasHeader)
    return LazHeader(
        file_source_ID = file_source_id(h),
        global_encoding = global_encoding(h),
        project_ID_GUID_data_1 = h.guid_1,
        project_ID_GUID_data_2 = h.guid_2,
        project_ID_GUID_data_3 = h.guid_3,
        project_ID_GUID_data_4 = h.guid_4,
        version_major = UInt8(las_version(h).major),
        version_minor = UInt8(las_version(h).minor),
        system_identifier = h.system_id,
        generating_software = h.software_id,
        file_creation_day = h.creation_dayofyear,
        file_creation_year = h.creation_year,
        header_size = header_size(h),
        offset_to_point_data = h.data_offset,
        number_of_variable_length_records = h.n_evlr,
        point_data_format = UInt8(get_point_format_id(point_format(h))),
        point_data_record_length = h.data_record_length,
        number_of_point_records = h.legacy_record_count,
        number_of_points_by_return = h.legacy_point_return_count,
        x_scale_factor = spatial_info(h).scale.x,
        y_scale_factor = spatial_info(h).scale.y,
        z_scale_factor = spatial_info(h).scale.z,
        x_offset = spatial_info(h).offset.x,
        y_offset = spatial_info(h).offset.y,
        z_offset = spatial_info(h).offset.z,
        max_x = spatial_info(h).range.x.max,
        min_x = spatial_info(h).range.x.min,
        max_y = spatial_info(h).range.y.max,
        min_y = spatial_info(h).range.y.min,
        max_z = spatial_info(h).range.z.max,
        min_z = spatial_info(h).range.z.min,
        start_of_waveform_data_packet_record = waveform_record_start(h),
        start_of_first_extended_variable_length_record = evlr_start(h),
        extended_number_of_point_records = h.record_count,
        extended_number_of_points_by_return = h.point_return_count
    )
end

function extract_laz_header_info(laz_header::LazHeader)
    xyz = SpatialInfo(
        AxisInfo(laz_header.x_scale_factor, laz_header.y_scale_factor, laz_header.z_scale_factor),
        AxisInfo(laz_header.x_offset, laz_header.y_offset, laz_header.z_offset),
        AxisInfo(Range(laz_header.max_x, laz_header.min_x), Range(laz_header.max_y, laz_header.min_y), Range(laz_header.max_z, laz_header.min_z))
    )
    header = LasHeader(
        VersionNumber(laz_header.version_major, laz_header.version_minor),
        laz_header.file_source_ID,
        laz_header.global_encoding,
        laz_header.project_ID_GUID_data_1,
        laz_header.project_ID_GUID_data_2,
        laz_header.project_ID_GUID_data_3,
        laz_header.project_ID_GUID_data_4,
        laz_header.system_identifier,
        laz_header.generating_software,
        laz_header.file_creation_day,
        laz_header.file_creation_year,
        laz_header.header_size,
        laz_header.offset_to_point_data,
        laz_header.number_of_variable_length_records,
        laz_header.point_data_format,
        laz_header.point_data_record_length,
        laz_header.number_of_point_records,
        laz_header.number_of_points_by_return,
        xyz,
        laz_header.start_of_waveform_data_packet_record,
        laz_header.start_of_first_extended_variable_length_record,
        laz_header.number_of_extended_variable_length_records,
        laz_header.extended_number_of_point_records,
        laz_header.extended_number_of_points_by_return
    )

    vlrs = Vector{LasVariableLengthRecord}(map(i -> convert(LasVariableLengthRecord, unsafe_load(laz_header.vlrs, i)), 1:laz_header.number_of_variable_length_records))

    user_defined_bytes = Vector{UInt8}(map(i -> unsafe_load(laz_header.user_data_after_header, i), 1:laz_header.user_data_after_header_size))

    return header, vlrs, user_defined_bytes
end