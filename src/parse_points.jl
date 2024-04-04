"""
A convenience function that creates a LasPoint from a given struct and some spatial information

$(METHODLIST)
"""
function laspoint end
laspoint(::Type{TPoint}, p::TPoint, xyz::SpatialInfo) where TPoint = p

byte_size(point::TPoint) where {N, TPoint <: LasPoint{N}} = byte_size(TPoint)
byte_size(::Type{TPoint}) where {N, TPoint <: LasPoint{N}} = sum(sizeof.(eltype.(fieldtypes(TPoint))))

byte_size(vector::Type{SVector{N,T}}) where {N,T} = sizeof(T) * N

"""
    $(TYPEDSIGNATURES)

Get the minimum point format that is compatible with the contents of a point cloud in a `table`
"""
function get_point_format(table::AbstractVector{<:NamedTuple})
    
    columns = columnnames(table)

    # these are the known formats - the ones without wave packets
    columns_per_format = map(n -> has_columns(get_point_format(LasPoint{n})), collect(0:9))

    # all las columns we care about:
    las_columns = unique(collect(Iterators.flatten(map(n -> [has_columns(get_point_format(LasPoint{n}))...], collect(0:9)))))
    
    # the data columns we'll use to looks for the best format
    data_columns = filter(c -> c in las_columns, columns)

    index = findfirst(fcols -> all(data_columns .∈ Ref(fcols)), columns_per_format)

    # Fall back to "best possible" format?
    @assert !isnothing(index) "No PointFormat found that can store your combination of columns."

    return get_point_format(LasPoint{index - 1})
end

"""
    $(TYPEDSIGNATURES)

Find out the minimum las version that you can use to write the data.
"""
function get_las_version_from_data(
    pc::AbstractVector{<:NamedTuple},   
    point_type::TPoint)::VersionNumber where TPoint
    
    if any([
        length(pc) > typemax(UInt32),
        haskey(pc, "returnnumber") && maximum(pc.returnnumber) > 5,
        haskey(pc, "scan_angle") && maximum(pc.scan_angle) > 90
    ])
        return v"1.4"
    end

    return lasversion_for_point(point_type)
end

# Extend base by enabling reading/writing relevant FixedPointNumbers from IO.
Base.read(io::IO, ::Type{N0f16}) = reinterpret(N0f16, read(io, UInt16))
Base.write(io::IO, t::N0f16) = write(io, reinterpret(UInt16, t))

# functions to access common LasPoint fields
"Angle at which the laser point was output, including the roll of the aircraft."
scan_angle(p::LasPoint_0_5) = 1.0 * p.scan_angle
scan_angle(p::LasPoint_6_10) = 0.006 * p.scan_angle

# color
"The red image channel value associated with this point"
ColorTypes.red(p::LasPointColor) = reinterpret(Normed{UInt16,16}, p.red)
"The green image channel value associated with this point"
ColorTypes.green(p::LasPointColor) = reinterpret(Normed{UInt16,16}, p.green)
"The blue image channel value associated with this point"
ColorTypes.blue(p::LasPointColor) = reinterpret(Normed{UInt16,16}, p.blue)
"The RGB color associated with this point"
ColorTypes.RGB(p::LasPointColor) = RGB(red(p), green(p), blue(p))

# functions to extract sub-byte items from a LasPoint's flag_byte
"The pulse return number for a given output pulse, starting at one."
# LasPoint_6_10: flag_byte_1::UInt8  # return number (4 bits) & number of returns (4 bits)
return_number(p::LasPoint_0_5) = (p.flag_byte & 0b00000111)
return_number(p::LasPoint_6_10) = (p.flag_byte_1 & 0b00001111)
"The total number of returns for a given pulse."
number_of_returns(p::LasPoint_0_5) = (p.flag_byte & 0b00111000) >> 3
number_of_returns(p::LasPoint_6_10) = (p.flag_byte_1 & 0b11110000) >> 4
"If true, the scanner mirror was traveling from left to right at the time of the output pulse."
scan_direction(p::LasPoint_0_5) = Bool((p.flag_byte & 0b01000000) >> 6)
scan_direction(p::LasPoint_6_10) = Bool((p.flag_byte_2 & 0b01000000) >> 6)

scanner_channel(p::LasPoint_6_10) = (p.flag_byte_2 & 0b00110000) >> 4
"If true, it is the last point before the scanner changes direction."
edge_of_flight_line(p::LasPoint_0_5) = Bool((p.flag_byte & 0b10000000) >> 7)
edge_of_flight_line(p::LasPoint_6_10) = Bool((p.flag_byte_2 & 0b10000000) >> 7)

"Flag byte, contains return number, number of returns, scan direction flag and edge of flight line"
flag_byte(p::LasPoint_0_5) = p.flag_byte
"Flag byte, as represented in the point data, built up from components"
function flag_byte(return_number::UInt8, number_of_returns::UInt8,
                   scan_direction::Bool, edge_of_flight_line::Bool)::UInt8
    # Bool to UInt8 conversion because a bit shift on a Bool produces an Int
    (UInt8(edge_of_flight_line) << 7) | (UInt8(scan_direction) << 6) | (number_of_returns << 3) | return_number
end

flag_byte_1(p::LasPoint_6_10) = p.flag_byte_1
flag_byte_2(p::LasPoint_6_10) = p.flag_byte_2
function flag_byte_1(return_number::UInt8, number_of_returns::UInt8)::UInt8
    number_of_returns << 4 | return_number
end

function flag_byte_2(
    synthetic::Bool,
    key_point::Bool,
    withheld::Bool,
    overlap::Bool,
    scanner_channel::UInt8,
    scan_direction::Bool,
    edge_of_flight_line::Bool,
)::UInt8
    UInt8(edge_of_flight_line) << 7 | UInt8(scan_direction) << 6 | UInt8(scanner_channel) << 4 | UInt8(overlap) << 3 | UInt8(withheld) << 2 | UInt8(key_point) << 1 | UInt8(synthetic)
end

# functions to extract sub-byte items from a LasPoint's raw_classification
"Classification value as defined in the ASPRS classification table."
classification(p::LasPoint_0_5) = (p.raw_classification & 0b00011111)
classification(p::LasPoint_6_10) = p.classification

# LasPoint_6_10 : flag_byte_2::UInt8 # classification flags, scanner channel, scan direction flag, edge of flight line
"If true, the point was not created from lidar collection"
synthetic(p::LasPoint_0_5)::Bool = (p.raw_classification & 0b00100000) >> 5
synthetic(p::LasPoint_6_10)::Bool = (p.flag_byte_2 & 0b00000001)
"If true, this point is considered to be a model key-point."
key_point(p::LasPoint_0_5)::Bool = (p.raw_classification & 0b01000000) >> 6
key_point(p::LasPoint_6_10)::Bool = (p.flag_byte_2 & 0b00000010) >> 1
"If true, this point should not be included in processing"
withheld(p::LasPoint_0_5)::Bool = (p.raw_classification & 0b10000000) >> 7
withheld(p::LasPoint_6_10)::Bool = (p.flag_byte_2 & 0b00000100) >> 2
"If true, this point is classified as an overlapping point with another data set"
overlap(p::LasPoint_6_10)::Bool = (p.flag_byte_2 & 0b00001000) >> 3

"Raw classification byte in LAS1.1-1.3, as represented in the point data, is built up from components"
function raw_classification(classification::UInt8, synthetic::Bool,
                            key_point::Bool, withheld::Bool)::UInt8
    UInt8(withheld) << 7 | UInt8(key_point) << 6 | UInt8(synthetic) << 5 | classification
end

get_integer_intensity(value) = denormalize(UInt16, value)
get_integer_intensity(p::LasPoint) = get_integer_intensity(get_intensity(p))

point_source_id(p::LasPoint) = p.pt_src_id

user_data(p::LasPoint) = p.user_data

function get_flag_byte(p::NamedTuple)
    flag_byte(
        clamp(get(p, :returnnumber, 0x01), 0x01, 0x05),
        clamp(get(p, :numberofreturns, 0x01), 0x01, 0x05),
        get(p, :scan_direction, false),
        get(p, :edge_of_flight_line, false),
    )
end

const flag_byte_content = (:returnnumber, :numberofreturns, :scan_direction, :edge_of_flight_line)

function get_classification_byte(p::NamedTuple)
    class = get(p, :classification, 0x00)
    raw_classification(
        class > 31 ? 0x00 : UInt8(class),
        get(p, :synthetic, false),
        get(p, :key_point, false),
        get(p, :withheld, false),
    )
end

const raw_classification_byte_content = (:synthetic, :key_point, :withheld, :classification)

function get_int(::Type{T}, value::Real, offset::Real, scale::Real) where T <: Integer
    scaled_and_clamped = clamp((value - offset) / scale, typemin(T), typemax(T))
    return round(T, scaled_and_clamped)
end

function get_int_xyz(::Type{TInt}, position::SVector{3, Float64}, xyz::SpatialInfo) where {TInt <: Integer}
    @inbounds x = get_int(TInt, position[1], xyz.offset.x, xyz.scale.x)
    @inbounds y = get_int(TInt, position[2], xyz.offset.y, xyz.scale.y)
    @inbounds z = get_int(TInt, position[3], xyz.offset.z, xyz.scale.z)
    return x,y,z
end

function get_position(point::T, xyz::SpatialInfo) where {N, T <: LasPoint{N}}
    SVector{3, Float64}(point.x * xyz.scale.x + xyz.offset.x,
                        point.y * xyz.scale.y + xyz.offset.y,
                        point.z * xyz.scale.z + xyz.offset.z)
end

function get_intensity(point::T)  where {N, T <: LasPoint{N}}
    return reinterpret(Normed{UInt16,16}, point.intensity)
end

function laspoint(
    ::Type{LasPoint0},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_data = get_flag_byte(p)
    raw_classification_data = get_classification_byte(p)
    scan_angle = haskey(p, :scan_angle) ? round(Int8, clamp(p.scan_angle, -90, 90)) : Int8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000

    return LasPoint0(
        x,
        y,
        z,
        intensity,
        flag_byte_data,
        raw_classification_data,
        scan_angle,
        user_data,
        pt_src_id,
    )
end

function has_columns end

has_columns(::Type{LasPoint0}) = (:position, :intensity, flag_byte_content..., raw_classification_byte_content..., :scan_angle, :user_data, :point_source_id)

function laspoint(
    ::Type{LasPoint1},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)

    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_data = get_flag_byte(p)
    raw_classification_data = get_classification_byte(p)
    scan_angle = haskey(p, :scan_angle) ? round(Int8, clamp(p.scan_angle, -90, 90)) : Int8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    gps_time = haskey(p, :gps_time) ? convert(Float64, p.gps_time) : 0.0

    return LasPoint1(
        x,
        y,
        z,
        intensity,
        flag_byte_data,
        raw_classification_data,
        scan_angle,
        user_data,
        pt_src_id,
        gps_time,
    )
end

has_columns(::Type{LasPoint1}) = (:position, :intensity, flag_byte_content..., raw_classification_byte_content..., :scan_angle, :user_data, :point_source_id, :gps_time)

function laspoint(
    ::Type{LasPoint2},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_data = get_flag_byte(p)
    raw_classification_data = get_classification_byte(p)
    scan_angle = haskey(p, :scan_angle) ? round(Int8, clamp(p.scan_angle, -90, 90)) : Int8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    red_channel = haskey(p, :color) ? denormalize(UInt16, p.color.r) : 0x0000
    green_channel = haskey(p, :color) ? denormalize(UInt16, p.color.g) :  0x0000
    blue_channel = haskey(p, :color) ? denormalize(UInt16, p.color.b) :  0x0000

    return LasPoint2(
        x,
        y,
        z,
        intensity,
        flag_byte_data,
        raw_classification_data,
        scan_angle,
        user_data,
        pt_src_id,
        red_channel,
        green_channel,
        blue_channel,
    )
end

has_columns(::Type{LasPoint2}) = (:position, :intensity, flag_byte_content..., raw_classification_byte_content..., :scan_angle, :user_data, :point_source_id, :color)

function laspoint(
    ::Type{LasPoint3},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_data = get_flag_byte(p)
    raw_classification_data = get_classification_byte(p)
    scan_angle = haskey(p, :scan_angle) ? round(Int8, clamp(p.scan_angle, -90, 90)) : Int8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    gps_time = haskey(p, :gps_time) ? convert(Float64, p.gps_time) : 0.0
    red_channel = haskey(p, :color) ? denormalize(UInt16, p.color.r) : 0x0000
    green_channel = haskey(p, :color) ? denormalize(UInt16, p.color.g) :  0x0000
    blue_channel = haskey(p, :color) ? denormalize(UInt16, p.color.b) :  0x0000

    return LasPoint3(
        x,
        y,
        z,
        intensity,
        flag_byte_data,
        raw_classification_data,
        scan_angle,
        user_data,
        pt_src_id,
        gps_time,
        red_channel,
        green_channel,
        blue_channel,
    )
end

has_columns(::Type{LasPoint3}) = (:position, :intensity, flag_byte_content..., raw_classification_byte_content..., :scan_angle, :user_data, :point_source_id, :color, :gps_time)

function laspoint(
    ::Type{LasPoint4},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_data = get_flag_byte(p)
    raw_classification_data = get_classification_byte(p)
    scan_angle = haskey(p, :scan_angle) ? round(Int8, clamp(p.scan_angle, -90, 90)) : Int8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    gps_time = haskey(p, :gps_time) ? convert(Float64, p.gps_time) : 0.0
    wave_packet_descriptor_index = UInt8(0)
    wave_packet_byte_offset = UInt64(0)
    wave_packet_size_in_bytes = UInt32(0)
    wave_return_location = Float32(0)
    wave_x_t = Float32(0)
    wave_y_t = Float32(0)
    wave_z_t = Float32(0)
    return LasPoint4(
        x,
        y,
        z,
        intensity,
        flag_byte_data,
        raw_classification_data,
        scan_angle,
        user_data,
        pt_src_id,
        gps_time,
        wave_packet_descriptor_index,
        wave_packet_byte_offset,
        wave_packet_size_in_bytes,
        wave_return_location,
        wave_x_t,
        wave_y_t,
        wave_z_t,
    )
end

has_columns(::Type{LasPoint4}) = (:position, :intensity, flag_byte_content..., raw_classification_byte_content..., :scan_angle, :user_data, :point_source_id, :gps_time)

function laspoint(
    ::Type{LasPoint5},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_data = get_flag_byte(p)
    raw_classification_data = get_classification_byte(p)
    scan_angle = haskey(p, :scan_angle) ? round(Int8, clamp(p.scan_angle, -90, 90)) : Int8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    gps_time = haskey(p, :gps_time) ? convert(Float64, p.gps_time) : 0.0
    red_channel = haskey(p, :color) ? denormalize(UInt16, p.color.r) : 0x0000
    green_channel = haskey(p, :color) ? denormalize(UInt16, p.color.g) :  0x0000
    blue_channel = haskey(p, :color) ? denormalize(UInt16, p.color.b) :  0x0000
    wave_packet_descriptor_index = UInt8(0)
    wave_packet_byte_offset = UInt64(0)
    wave_packet_size_in_bytes = UInt32(0)
    wave_return_location = Float32(0)
    wave_x_t = Float32(0)
    wave_y_t = Float32(0)
    wave_z_t = Float32(0)
    return LasPoint5(
        x,
        y,
        z,
        intensity,
        flag_byte_data,
        raw_classification_data,
        scan_angle,
        user_data,
        pt_src_id,
        gps_time,
        red_channel,
        green_channel,
        blue_channel,
        wave_packet_descriptor_index,
        wave_packet_byte_offset,
        wave_packet_size_in_bytes,
        wave_return_location,
        wave_x_t,
        wave_y_t,
        wave_z_t,
    )
end

has_columns(::Type{LasPoint5}) = (:position, :intensity, flag_byte_content..., raw_classification_byte_content..., :scan_angle, :user_data, :point_source_id, :gps_time, :color)

function get_flag_byte_1(p::NamedTuple)
    flag_byte_1(
        clamp(get(p, :returnnumber, 0x01), 0x01, 0x0f),
        clamp(get(p, :numberofreturns, 0x01), 0x01, 0x0f),
    )
end

function get_flag_byte_2(p::NamedTuple)
    flag_byte_2(
        get(p, :synthetic, false),
        get(p, :key_point, false),
        get(p, :withheld, false),
        get(p, :overlap, false),
        clamp(get(p, :scanner_channel, 0x00), 0x00, 0x03),
        get(p, :scan_direction, false),
        get(p, :edge_of_flight_line, false),
    )
end

const las14_flag_byte_content = (:synthetic, :key_point, :withheld, :overlap, :scanner_channel, :scan_direction, :edge_of_flight_line, :returnnumber, :numberofreturns)

function laspoint(
    ::Type{LasPoint6},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_1_data = get_flag_byte_1(p)
    flag_byte_2_data = get_flag_byte_2(p)
    classification =
        haskey(p, :classification) ? convert(UInt8, p.classification) : UInt8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    scan_angle = haskey(p, :scan_angle) ? round(Int16, clamp(p.scan_angle / 0.006, -30_000, 30_000)) : Int16(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    gps_time = haskey(p, :gps_time) ? convert(Float64, p.gps_time) : 0.0

    return LasPoint6(
        x,
        y,
        z,
        intensity,
        flag_byte_1_data,
        flag_byte_2_data,
        classification,
        user_data,
        scan_angle,
        pt_src_id,
        gps_time,
    )
end

has_columns(::Type{LasPoint6}) = (:position, :intensity, :classification, las14_flag_byte_content..., :scan_angle, :user_data, :point_source_id, :gps_time)

function laspoint(
    ::Type{LasPoint7},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_1_data = get_flag_byte_1(p)
    flag_byte_2_data = get_flag_byte_2(p)
    classification =
        haskey(p, :classification) ? convert(UInt8, p.classification) : UInt8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    scan_angle = haskey(p, :scan_angle) ? round(Int16, clamp(p.scan_angle / 0.006, -30_000, 30_000)) : Int16(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    gps_time = haskey(p, :gps_time) ? convert(Float64, p.gps_time) : 0.0
    red_channel = haskey(p, :color) ? denormalize(UInt16, p.color.r) : 0x0000
    green_channel = haskey(p, :color) ? denormalize(UInt16, p.color.g) :  0x0000
    blue_channel = haskey(p, :color) ? denormalize(UInt16, p.color.b) :  0x0000

    return LasPoint7(
        x,
        y,
        z,
        intensity,
        flag_byte_1_data,
        flag_byte_2_data,
        classification,
        user_data,
        scan_angle,
        pt_src_id,
        gps_time,
        red_channel,
        green_channel,
        blue_channel,
    )
end

has_columns(::Type{LasPoint7}) = (:position, :intensity, :classification, las14_flag_byte_content..., :scan_angle, :user_data, :point_source_id, :gps_time, :color)

function laspoint(
    ::Type{LasPoint8},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_1_data = get_flag_byte_1(p)
    flag_byte_2_data = get_flag_byte_2(p)
    classification =
        haskey(p, :classification) ? convert(UInt8, p.classification) : UInt8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    scan_angle = haskey(p, :scan_angle) ? round(Int16, clamp(p.scan_angle / 0.006, -30_000, 30_000)) : Int16(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    gps_time = haskey(p, :gps_time) ? convert(Float64, p.gps_time) : 0.0
    red_channel = haskey(p, :color) ? denormalize(UInt16, p.color.r) : 0x0000
    green_channel = haskey(p, :color) ? denormalize(UInt16, p.color.g) :  0x0000
    blue_channel = haskey(p, :color) ? denormalize(UInt16, p.color.b) :  0x0000
    nir = haskey(p, :nir) ? denormalize(UInt16, p.nir) :  0x0000

    return LasPoint8(
        x,
        y,
        z,
        intensity,
        flag_byte_1_data,
        flag_byte_2_data,
        classification,
        user_data,
        scan_angle,
        pt_src_id,
        gps_time,
        red_channel,
        green_channel,
        blue_channel,
        nir,
    )
end

has_columns(::Type{LasPoint8}) = (:position, :intensity, :classification, las14_flag_byte_content..., :scan_angle, :user_data, :point_source_id, :gps_time, :color, :nir)

function laspoint(
    ::Type{LasPoint9},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_1_data = get_flag_byte_1(p)
    flag_byte_2_data = get_flag_byte_2(p)
    classification =
        haskey(p, :classification) ? convert(UInt8, p.classification) : UInt8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    scan_angle = haskey(p, :scan_angle) ? round(Int16, clamp(p.scan_angle / 0.006, -30_000, 30_000)) : Int16(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    gps_time = haskey(p, :gps_time) ? convert(Float64, p.gps_time) : 0.0
    wave_packet_descriptor_index = UInt8(0)
    wave_packet_byte_offset = UInt64(0)
    wave_packet_size_in_bytes = UInt32(0)
    wave_return_location = Float32(0)
    wave_x_t = Float32(0)
    wave_y_t = Float32(0)
    wave_z_t = Float32(0)

    return LasPoint9(
        x,
        y,
        z,
        intensity,
        flag_byte_1_data,
        flag_byte_2_data,
        classification,
        user_data,
        scan_angle,
        pt_src_id,
        gps_time,
        wave_packet_descriptor_index,
        wave_packet_byte_offset,
        wave_packet_size_in_bytes,
        wave_return_location,
        wave_x_t,
        wave_y_t,
        wave_z_t,
    )
end

has_columns(::Type{LasPoint9}) = (:position, :intensity, :classification, las14_flag_byte_content..., :scan_angle, :user_data, :point_source_id, :gps_time)

function laspoint(
    ::Type{LasPoint10},
    p::NamedTuple,
    xyz,
)
    position = p.position
    x,y,z = get_int_xyz(Int32, position, xyz)
    intensity = haskey(p, :intensity) ? get_integer_intensity(p.intensity) : 0x0000
    flag_byte_1_data = get_flag_byte_1(p)
    flag_byte_2_data = get_flag_byte_2(p)
    classification =
        haskey(p, :classification) ? convert(UInt8, p.classification) : UInt8(0)
    user_data = haskey(p, :user_data) ? convert(UInt8, p.user_data) : UInt8(0)
    scan_angle = haskey(p, :scan_angle) ? round(Int16, clamp(p.scan_angle / 0.006, -30_000, 30_000)) : Int16(0)
    pt_src_id = haskey(p, :point_source_id) ? convert(UInt16, p.point_source_id) : 0x0000
    gps_time = haskey(p, :gps_time) ? convert(Float64, p.gps_time) : 0.0
    red_channel = haskey(p, :color) ? denormalize(UInt16, p.color.r) : 0x0000
    green_channel = haskey(p, :color) ? denormalize(UInt16, p.color.g) :  0x0000
    blue_channel = haskey(p, :color) ? denormalize(UInt16, p.color.b) :  0x0000
    nir = haskey(p, :nir) ? denormalize(UInt16, p.nir) :  0x0000
    wave_packet_descriptor_index = UInt8(0)
    wave_packet_byte_offset = UInt64(0)
    wave_packet_size_in_bytes = UInt32(0)
    wave_return_location = Float32(0)
    wave_x_t = Float32(0)
    wave_y_t = Float32(0)
    wave_z_t = Float32(0)

    return LasPoint10(
        x,
        y,
        z,
        intensity,
        flag_byte_1_data,
        flag_byte_2_data,
        classification,
        user_data,
        scan_angle,
        pt_src_id,
        gps_time,
        red_channel,
        green_channel,
        blue_channel,
        nir,
        wave_packet_descriptor_index,
        wave_packet_byte_offset,
        wave_packet_size_in_bytes,
        wave_return_location,
        wave_x_t,
        wave_y_t,
        wave_z_t,
    )
end

struct Extractor{T} 
    xyz::SpatialInfo
end

"""
    get_field_name(extractor::Extractor{TColumn}, point_type::Type{TPoint}) where {TPoint, TColumn} 

Gets the field name in the `point_type` for column `TColumn`.
"""
function get_field_name end
get_field_name(extractor::Extractor{T}, point_type::Type) where {T} = T
get_field_name(extractor::Extractor{:point_source_id}, point_type::Type{TPoint}) where {N, TPoint <: LasPoint{N}} = :pt_src_id

function get_column end
get_column(extractor::Extractor, laspoint::P) where {N, P <: LasPoint{N}} = getfield(laspoint, get_field_name(extractor, P))
get_column(extractor::Extractor{:position}, laspoint::P) where {N, P <: LasPoint{N}}  = get_position(laspoint, extractor.xyz)
get_column(extractor::Extractor{:intensity}, laspoint::P) where {N, P <: LasPoint{N}}  = get_intensity(laspoint)
get_column(extractor::Extractor{:color}, laspoint::P) where {N, P <: LasPoint{N}}  =  ColorTypes.RGB(laspoint)
get_column(extractor::Extractor{:nir}, laspoint::P) where {N, P <: LasPoint{N}}  = reinterpret(Normed{UInt16,16}, laspoint.nir)
get_column(extractor::Extractor{:synthetic}, laspoint::P) where {N, P <: LasPoint{N}}  = synthetic(laspoint)
get_column(extractor::Extractor{:key_point}, laspoint::P) where {N, P <: LasPoint{N}}  = key_point(laspoint)
get_column(extractor::Extractor{:withheld}, laspoint::P) where {N, P <: LasPoint{N}}  = withheld(laspoint)
get_column(extractor::Extractor{:overlap}, laspoint::P) where {N, P <: LasPoint{N}}  = overlap(laspoint)
get_column(extractor::Extractor{:scanner_channel}, laspoint::P) where {N, P <: LasPoint{N}}  = scanner_channel(laspoint)
get_column(extractor::Extractor{:edge_of_flight_line}, laspoint::P) where {N, P <: LasPoint{N}}  = edge_of_flight_line(laspoint)
get_column(extractor::Extractor{:returnnumber}, laspoint::P) where {N, P <: LasPoint{N}} = return_number(laspoint)
get_column(extractor::Extractor{:numberofreturns}, laspoint::P) where {N, P <: LasPoint{N}} = number_of_returns(laspoint)
get_column(extractor::Extractor{:scan_direction}, laspoint::P) where {N, P <: LasPoint{N}} = scan_direction(laspoint)
get_column(extractor::Extractor{:classification}, laspoint::P) where {N, P <: LasPoint{N}} = classification(laspoint)
get_column(extractor::Extractor{:scan_angle}, laspoint::P) where {N, P <: LasPoint{N}} = scan_angle(laspoint)