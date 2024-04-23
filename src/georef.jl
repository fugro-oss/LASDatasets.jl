"""
    $(TYPEDEF)

A key entry for a piece o0f GeoTIFF data

$(TYPEDFIELDS)
"""
struct KeyEntry
    """Defined key ID for each piece of GeoTIFF data. IDs contained in the GeoTIFF specification"""
    keyid::UInt16
    
    """Indicates where the data for this key is located"""
    tiff_tag_location::UInt16

    """Number of characters in string for values of GeoAsciiParamsTag, otherwise is 1"""
    count::UInt16

    """Contents vary depending on value for `tiff_tag_location` above"""
    value_offset::UInt16
end

Base.sizeof(k::KeyEntry) = 8

Base.:(==)(k1::KeyEntry, k2::KeyEntry) = all([
    k1.keyid == k2.keyid,
    k1.tiff_tag_location == k2.tiff_tag_location,
    k1.count == k2.count,
    k1.value_offset == k2.value_offset
])

@reflect KeyEntry

"""
    $(TYPEDEF)

Contains the TIFF keys that defines a coordinate system. A complete description can
be found in the GeoTIFF format specification. 

As per the spec:
* `key_directory_version = 1` always
* `key_revision = 1` always
* `minor_revision = 0` always

This may change in future LAS spec versions
"""
struct GeoKeys
    key_directory_version::UInt16
    key_revision::UInt16
    minor_revision::UInt16
    number_of_keys::UInt16
    keys::Vector{KeyEntry}
end

# version numbers are fixed in the LAS specification
GeoKeys(keys::Vector{KeyEntry}) = GeoKeys(0x0001, 0x0001, 0x0000, UInt16(length(keys)), keys)

"Create GeoKeys from EPSG code. Assumes CRS is projected and in metres."
function GeoKeys(epsg::Integer)
    #Standard types
    is_projected = KeyEntry(UInt16(1024), UInt16(0), UInt16(1), UInt16(1))         # Projected
    proj_linear_units = KeyEntry(UInt16(1025), UInt16(0), UInt16(1), UInt16(1))    # Units in meter
    projected_cs_type = KeyEntry(UInt16(3072), UInt16(0), UInt16(1), UInt16(epsg)) # EPSG code
    vertical_units = KeyEntry(UInt16(3076), UInt16(0), UInt16(1), UInt16(9001))    # Units in meter
    keys = [is_projected, proj_linear_units, projected_cs_type, vertical_units]
    GeoKeys(keys)
end

Base.:(==)(k1::GeoKeys, k2::GeoKeys) = all([
    k1.key_directory_version == k2.key_directory_version,
    k1.key_revision == k2.key_revision,
    k1.minor_revision == k2.minor_revision,
    k1.number_of_keys == k2.number_of_keys,
    length(k1.keys) == length(k2.keys),
    all(k1.keys .== k2.keys)
])

Base.sizeof(data::GeoKeys) = sum(sizeof.(data.keys)) + 8

function Base.write(io::IO, data::GeoKeys)
    write(io, data.key_directory_version)
    write(io, data.key_revision)
    write(io, data.minor_revision)
    write(io, data.number_of_keys)
    for keyEntry in data.keys
        write_struct(io, keyEntry)
    end
end

function Base.read(io::IO, ::Type{GeoKeys})
    key_directory_version = read(io, UInt16)
    key_revision = read(io, UInt16)
    minor_revision = read(io, UInt16)
    number_of_keys = read(io, UInt16)
    keys = KeyEntry[]
    for i in 1:number_of_keys
        keyid = read(io, UInt16)
        tiff_tag_location = read(io, UInt16)
        count = read(io, UInt16)
        value_offset = read(io, UInt16)
        push!(keys, KeyEntry(
            keyid,
            tiff_tag_location,
            count,
            value_offset
        ))
    end
    return GeoKeys(
        key_directory_version,
        key_revision,
        minor_revision,
        number_of_keys,
        keys
    )
end

@register_vlr_type GeoKeys LAS_PROJ_USER_ID ID_GEOKEYDIRECTORYTAG

"""
    $(TYPEDEF)

A collection of values `double_params` that are referenced by tag sets in a `GeoKeys` record
"""
struct GeoDoubleParamsTag
    double_params::Vector{Float64}
end

Base.:(==)(t1::GeoDoubleParamsTag, t2::GeoDoubleParamsTag) = (t1.double_params == t2.double_params)

Base.sizeof(data::GeoDoubleParamsTag) = sizeof(data.double_params)

Base.write(io::IO, data::GeoDoubleParamsTag) = write(io, data.double_params)

@register_vlr_type GeoDoubleParamsTag LAS_PROJ_USER_ID ID_GEODOUBLEPARAMSTAG

function read_vlr_data(io::IO, ::Type{GeoDoubleParamsTag}, nb::Integer)
    double_params = zeros(nb ÷ 8)
    read!(io, double_params)
    return GeoDoubleParamsTag(double_params)
end

"""
    $(TYPEDEF)

An array of ASCII data that contains many strings separated by null terminator characters in `ascii_params`.
These are referenced by position from the data in a `GeoKeys` record
"""
struct GeoAsciiParamsTag
    ascii_params::String
    nb::Int  # number of bytes
    GeoAsciiParamsTag(s::AbstractString, nb::Integer) = new(ascii(s), Int(nb))
end

Base.:(==)(t1::GeoAsciiParamsTag, t2::GeoAsciiParamsTag) = (t1.ascii_params == t2.ascii_params) && (t1.nb == t2.nb)

Base.sizeof(data::GeoAsciiParamsTag) = data.nb
Base.write(io::IO, data::GeoAsciiParamsTag) = writestring(io, data.ascii_params, data.nb)

@register_vlr_type GeoAsciiParamsTag LAS_PROJ_USER_ID ID_GEOASCIIPARAMSTAG

function read_vlr_data(io::IO, ::Type{GeoAsciiParamsTag}, nb::Integer)
    ascii_params = readstring(io, nb)
    return GeoAsciiParamsTag(ascii_params, nb)
end

"""
    $(TYPEDEF)

A Coordinate System WKT record specified by the Open Geospatial Consortium (OGC) spec

$(TYPEDFIELDS)
"""
struct OGC_WKT
    """The WKT formatted string for the coordinate system"""
    wkt_str::String

    """Number of bytes in the WKT string"""
    nb::Int

    """Units applied along the horizontal (XY) plane in this coordinate system"""
    unit::Union{Missing, String}

    """Units applied along the vertical (Z) axis in this coordinate system. Note: this will not in general match the horizontal coordinate"""
    vert_unit::Union{Missing, String}
end

Base.:(==)(w1::OGC_WKT, w2::OGC_WKT) = all([
    w1.wkt_str == w2.wkt_str,
    w1.nb == w2.nb,
    (ismissing(w1.unit) && ismissing(w2.unit)) || !ismissing(w1.unit) && !ismissing(w2.unit) && (w1.unit == w2.unit),
    (ismissing(w1.vert_unit) && ismissing(w2.vert_unit)) || !ismissing(w1.vert_unit) && !ismissing(w2.vert_unit) && (w1.vert_unit == w2.vert_unit)
])

Base.sizeof(ogc_wkt::OGC_WKT) = ogc_wkt.nb

function Base.write(io::IO, ogc_wkt::OGC_WKT)
    writestring(io, ogc_wkt.wkt_str, ogc_wkt.nb)
end

@register_vlr_type OGC_WKT LAS_PROJ_USER_ID ID_OGCWKTTAG

function read_vlr_data(io::IO, ::Type{OGC_WKT}, nb::Int)
    wkt_str = readstring(io, nb)
    return OGC_WKT(wkt_str, nb)
end

function OGC_WKT(wkt_string::String, nb::Int = sizeof(wkt_string))
    # try and parse the wkt string
    src = missing
    unit = vert_unit = missing
    try
        src = importWKT(replace(wkt_string, '\0' => ""))

        proj_str = toPROJ4(src)

        units = split(proj_str)[findall(s -> startswith(s, "+units="), split(proj_str))]
    
        if length(units) == 1
            unit = String(split(units[1], "=")[2])
            vert_units = split(proj_str)[findall(s -> startswith(s, "+vunits="), split(proj_str))]
    
            vert_unit = unit
            if length(vert_units) == 1
                vert_unit = String(split(vert_units[1], "=")[2])
            elseif length(vert_units) > 1
                @warn "2 vertical units found $(vert_units)"
            end
        elseif length(units) > 1
            @warn "2 units found $(units)"
        end
    catch
        @warn "Can't parse $(wkt_string) check/fix format"
    end

    return OGC_WKT(wkt_string, nb, unit, vert_unit)
end

get_wkt_string(ogc_wkt::OGC_WKT) = ogc_wkt.wkt_str
get_horizontal_unit(ogc_wkt::OGC_WKT) = ogc_wkt.unit
get_vertical_unit(ogc_wkt::OGC_WKT) = ogc_wkt.vert_unit

"""
    $(TYPEDSIGNATURES)

Given an OGC WKT coordinate system `wkt`, attempt to parse conversion units (to metres) with optional operator supplied overrides.
Can opt to convert all axes units or just the vertical.
"""
function conversion_from_vlrs(wkt::OGC_WKT; 
                                convert_x_y_units::Union{String, Missing} = missing, 
                                convert_z_units::Union{String, Missing} = missing)::Union{Missing, SVector{3}}
    
    unit = get_horizontal_unit(wkt)
    v_unit = get_vertical_unit(wkt)

    # Overwrite with operator specified units
    if !ismissing(convert_x_y_units)
        if ismissing(unit) 
            unit = convert_x_y_units
        elseif convert_x_y_units != unit
            @warn "You say x/y/z units are $(convert_x_y_units), but las header says $(unit) -- hope you're right!"
            unit = convert_x_y_units
        end
    end

    if !ismissing(convert_z_units)
        if ismissing(v_unit)
            v_unit = convert_z_units
        elseif convert_z_units != v_unit
            @warn "You say z units are $(convert_z_units), but las header says $(v_unit) -- hope you're right!"
            v_unit = convert_z_units
        end
    end

    return units_to_conversion(unit, v_unit)
end

"""
    $(TYPEDSIGNATURES)

Parse the specified units into a conversion vector.
"""
function units_to_conversion(unit::Union{String, Missing}, v_unit::Union{String, Missing} = missing)::Union{Missing, SVector{3}}

    conversion_xy = 1.0
    if !ismissing(unit)
        conversion_xy = get(UNIT_CONVERSION, unit, missing)
        if ismissing(conversion_xy)
            @warn "Can't find conversion factor for unit: $(unit)"
            return missing
        end
    end

    conversion_z = conversion_xy
    if !ismissing(v_unit)
        conversion_z = get(UNIT_CONVERSION, v_unit, missing)
        if ismissing(conversion_z)
            @warn "Can't find conversion factor for unit: $(v_unit)"
            return missing
        end
    end

    return SVector{3}(conversion_xy, conversion_xy, conversion_z)
end

units_to_conversion(unit::Missing, v_unit::Missing) = missing