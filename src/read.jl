"""
    $(TYPEDSIGNATURES)

Load a LAS dataset from a source file

# Arguments
* `file_name` : Name of the LAS file to extract data from
* `fields` : Name of the LAS point fields to extract as columns in the output data. Default `DEFAULT_LAS_COLUMNS`
"""
function load_las(file_name::AbstractString, 
    fields::TFields = DEFAULT_LAS_COLUMNS;
    kwargs...) where {TFields}

    open_func = get_open_func(file_name)

    las = open_func(file_name, "r") do io
        read_las_data(io, fields; kwargs...)
    end

    return las
end

"""
    $(TYPEDSIGNATURES)

Ingest LAS point data in a tabular format
"""
function load_pointcloud(file_name::AbstractString, fields::AbstractVector{Symbol} = collect(DEFAULT_LAS_COLUMNS); kwargs...)
    las = load_las(file_name, fields; kwargs...)
    return get_pointcloud(las)
end


"""
    $(TYPEDSIGNATURES)

Ingest a LAS header from a file
"""
function load_header(file_name::AbstractString)
    if is_laz(file_name)
        header, _, _ = read_laz_header_and_vlrs(file_name)
        return header
    else
        header = open_las(file_name, "r") do io
            read(io, LasHeader)
        end
        return header
    end
end

load_header(io::IO) = read(seek(io, 0), LasHeader)

"""
    $(TYPEDSIGNATURES)

Ingest a set of variable length records from a LAS file
"""
function load_vlrs(file_name::AbstractString, header::LasHeader)
    vlrs = open_las(file_name, "r") do io
        load_vlrs(io, header)
    end
    return vlrs
end

function load_vlrs(file_name::AbstractString)
    if is_laz(file_name)
        _, vlrs, _ = read_laz_header_and_vlrs(file_name)
        return vlrs
    else
        vlrs = open_las(file_name, "r") do io
            header = read(io, LasHeader)
            load_vlrs(io, header)
        end
        return vlrs
    end
end

"""
    $(TYPEDSIGNATURES)

Read LAS data from an IO source

# Arguments
* `io` : IO Channel to read the data in from
* `required_columns` : Point record fields to extract as columns in the output data, default `DEFAULT_LAS_COLUMNS`

### Keyword Arguments
* `convert_x_y_z_units` : Name of the units used to measure point coordinates in the LAS file that will be converted to metres when ingested. Set to `missing` for no conversion (default `missing`)
* `convert_z_units` : Name of the units on the z-axis in the LAS file that will be converted to metres when ingested. Set to `missing` for no conversion (default `missing`)
"""
function read_las_data(io::TIO, required_columns::TTuple=DEFAULT_LAS_COLUMNS;
                        convert_x_y_z_units::Union{String, Missing} = missing, 
                        convert_z_units::Union{String, Missing} = missing) where {TIO <: Union{Base.AbstractPipe,IO}, TTuple}

    header = read(io, LasHeader)

    @assert number_of_points(header) > 0 "Las file has no points!"

    vlrs = Vector{LasVariableLengthRecord}(map(_ -> read(io, LasVariableLengthRecord, false), 1:number_of_vlrs(header)))

    vlr_length = header.n_vlr == 0 ? 0 : sum(sizeof.(vlrs))
    pos = header.header_size + vlr_length
    user_defined_bytes = read(io, header.data_offset - pos)

    extra_bytes = Vector{ExtraBytes}(map(vlr -> get_data(vlr), extract_vlr_type(vlrs, LAS_SPEC_USER_ID, ID_EXTRABYTES)))

    this_format = record_format(header, extra_bytes)
    
    xyz = spatial_info(header)
    records = map(_ -> read(io, this_format), 1:number_of_points(header))

    as_table = make_table(records, required_columns, xyz)

    convert_units!(as_table, vlrs, convert_x_y_z_units, convert_z_units)

    evlrs = Vector{LasVariableLengthRecord}(map(_ -> read(io, LasVariableLengthRecord, true), 1:number_of_evlrs(header)))

    LasContent(header, as_table, vlrs, evlrs, user_defined_bytes)
end

function make_table(records::Vector{PointRecord{TPoint}}, required_columns::TTuple, xyz::SpatialInfo) where {TPoint <: LasPoint, TTuple}
    las_columns = (isnothing(required_columns) || isempty(required_columns)) ? has_columns(TPoint) : filter(c -> c in required_columns, has_columns(TPoint))
    extractors = map(c -> Extractor{c}(xyz), las_columns)
    Table(NamedTuple{ (las_columns...,) }( (map(e -> get_column.(Ref(e), records), extractors)...,) ))
end

function make_table(records::Vector{ExtendedPointRecord{TPoint, Names, Types}}, required_columns::TTuple, xyz::SpatialInfo) where {TPoint <: LasPoint, Names, Types, TTuple}
    las_columns = (isnothing(required_columns) || isempty(required_columns)) ? has_columns(TPoint) : filter(c -> c in required_columns, has_columns(TPoint))
    user_fields = filter(field -> field ∈ required_columns, Names)
    extractors = map(c -> Extractor{c}(xyz), las_columns)
    Table(NamedTuple{ (las_columns..., user_fields...,) }( (map(e -> get_column.(Ref(e), records), extractors)..., map(field -> getproperty.(getproperty.(records, :user_fields), field), user_fields)...) ))
end

function convert_units!(as_table::AbstractVector{<:NamedTuple}, vlrs::Vector{LasVariableLengthRecord}, convert_x_y_z_units::Union{Missing, Bool}, convert_z_units::Union{Missing, Bool})
    if :position ∈ columnnames(as_table)
        if !ismissing(convert_x_y_z_units) && !ismissing(convert_z_units)
            these_are_wkts = is_ogc_wkt_record.(vlrs)
            @assert count(these_are_wkts) == 1 "Expected to find 1 OGC WKT VLR, instead found $(count(these_are_wkts))"

            ogc_wkt = vlrs[findfirst(these_are_wkts)]
            conversion = conversion_from_vlrs(ogc_wkt, convert_x_y_z_units = convert_x_y_z_units, convert_z_units = convert_z_units)
            if !ismissing(conversion) && any(conversion .!= 1.0)
                @info "Positions converted to meters using conversion $(conversion)"
                as_table = as_table.position .= map(p -> p .* conversion, as_table.position)
            end
        end
    end
end