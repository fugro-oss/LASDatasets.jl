"""
    $(TYPEDSIGNATURES)

Load a LAS dataset from a source file

# Arguments
* `file_name` : Name of the LAS file to extract data from
* `fields` : Name of the LAS point fields to extract as columns in the output data. If set to `nothing`, ingest all available columns. Default `DEFAULT_LAS_COLUMNS`
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
function load_pointcloud(file_name::AbstractString, fields::Union{Nothing, AbstractVector{Symbol}} = collect(DEFAULT_LAS_COLUMNS); kwargs...)
    las = load_las(file_name, fields; kwargs...)
    return get_pointcloud(las)
end


"""
    $(TYPEDSIGNATURES)

Ingest a LAS header from a file
"""
function load_header(file_name::AbstractString)
    open_func = get_open_func(file_name)

    header = open_func(file_name, "r") do io
        read(io, LasHeader)
    end
    return header
end

load_header(io::IO) = read(seek(io, 0), LasHeader)

"""
    $(TYPEDSIGNATURES)

Ingest a set of variable length records from a LAS file

$(METHODLIST)
"""
function load_vlrs(file_name::AbstractString, header::LasHeader)
    open_func = get_open_func(file_name)
    vlrs = open_func(file_name, "r") do io
        seek(io, header_size(header))
        load_vlrs(io, header)
    end
    return vlrs
end

function load_vlrs(file_name::AbstractString)
    open_func = get_open_func(file_name)
    vlrs = open_func(file_name, "r") do io
        header = read(io, LasHeader)
        load_vlrs(io, header)
    end
    return vlrs
end


function load_vlrs(io::IO, header::LasHeader)
    Vector{LasVariableLengthRecord}(map(_ -> read(io, LasVariableLengthRecord, false), 1:number_of_vlrs(header)))
end

"""
    $(TYPEDSIGNATURES)

Read LAS data from an IO source

# Arguments
* `io` : IO Channel to read the data in from
* `required_columns` : Point record fields to extract as columns in the output data, default `DEFAULT_LAS_COLUMNS`

### Keyword Arguments
* `convrt_to_metres` : Flag indicating that point coordinates will be converted to metres upon reading, default true
* `convert_x_y_units` : Name of the units used to measure point coordinates in the LAS file that will be converted to metres when ingested. Set to `missing` for no conversion (default `missing`)
* `convert_z_units` : Name of the units on the z-axis in the LAS file that will be converted to metres when ingested. Set to `missing` for no conversion (default `missing`)
"""
function read_las_data(io::TIO, required_columns::TTuple=DEFAULT_LAS_COLUMNS;
                        convert_to_metres::Bool = true,
                        convert_x_y_units::Union{String, Missing} = missing, 
                        convert_z_units::Union{String, Missing} = missing) where {TIO <: Union{Base.AbstractPipe,IO}, TTuple}

    header = read(io, LasHeader)

    @assert number_of_points(header) > 0 "Las file has no points!"

    vlrs = load_vlrs(io, header)

    vlr_length = header.n_vlr == 0 ? 0 : sum(sizeof.(vlrs))
    pos = header.header_size + vlr_length
    user_defined_bytes = read(io, header.data_offset - pos)

    extra_bytes_vlr = extract_vlr_type(vlrs, LAS_SPEC_USER_ID, ID_EXTRABYTES)
    @assert length(extra_bytes_vlr) ≤ 1 "Found multiple extra bytes columns!"
    extra_bytes = isempty(extra_bytes_vlr) ? ExtraBytes[] : get_extra_bytes(get_data(extra_bytes_vlr[1]))

    this_format = record_format(header, extra_bytes)
    xyz = spatial_info(header)
    
    # using an iterator is approx 2x faster than simply doing map(_ -> read(io, T), 1:N)
    iter = ReadPointsIterator{TIO, this_format}(io, number_of_points(header))
    records = map(r -> r, iter)
    
    as_table = make_table(records, required_columns, xyz)

    if convert_to_metres
        conversion = convert_units!(as_table, vlrs, convert_x_y_units, convert_z_units)
    end

    evlrs = Vector{LasVariableLengthRecord}(map(_ -> read(io, LasVariableLengthRecord, true), 1:number_of_evlrs(header)))

    LasDataset(header, as_table, vlrs, evlrs, user_defined_bytes, conversion)
end

"""
    $(TYPEDSIGNATURES)

Convert a collection of LAS point records into a `Table` with the desired columns

# Arguments
* `records` : A collection of `LasRecord`s that have been read from a LAS file
* `required_columns` : Set of columns to include in the table being constructed
* `xyz` : Spatial information used to apply scaling/offset factors to point positions

$(METHODLIST)
"""
function make_table(records::Vector{PointRecord{TPoint}}, required_columns::TTuple, xyz::SpatialInfo) where {TPoint <: LasPoint, TTuple}
    las_columns, extractors = get_cols_and_extractors(TPoint, required_columns, xyz)
    Table(NamedTuple{ (las_columns...,) }( (map(e -> get_column.(Ref(e), records), extractors)...,) ))
end

function make_table(records::Vector{ExtendedPointRecord{TPoint, Names, Types}}, required_columns::TTuple, xyz::SpatialInfo) where {TPoint <: LasPoint, Names, Types, TTuple}
    las_columns, extractors = get_cols_and_extractors(TPoint, required_columns, xyz)
    user_fields, grouped_user_fields = get_user_fields_for_table(records, Names, required_columns)
    Table(NamedTuple{ (las_columns..., user_fields...,) }( (
        map(e -> get_column.(Ref(e), records), extractors)..., 
        grouped_user_fields...
    ) ))
end

function make_table(records::Vector{UndocPointRecord{TPoint, N}}, required_columns::TTuple, xyz::SpatialInfo) where {TPoint <: LasPoint, N, TTuple}
    las_columns, extractors = get_cols_and_extractors(TPoint, required_columns, xyz)
    Table(NamedTuple{ (las_columns..., :undocumented_bytes) }( (map(e -> get_column.(Ref(e), records), extractors)..., get_undocumented_bytes.(records)) ))
end

function make_table(records::Vector{FullRecord{TPoint, Names, Types, N}}, required_columns::TTuple, xyz::SpatialInfo) where {TPoint <: LasPoint, Names, Types, N, TTuple}
    las_columns, extractors = get_cols_and_extractors(TPoint, required_columns, xyz)
    user_fields, grouped_user_fields = get_user_fields_for_table(records, Names, required_columns)
    Table(NamedTuple{ (las_columns..., user_fields..., :undocumented_bytes) }( (
            map(e -> get_column.(Ref(e), records), extractors)..., 
            grouped_user_fields...,
            get_undocumented_bytes.(records)
        ) ))
end

"""
    $(TYPEDSIGNATURES)

Helper function that gets the compatible column names from a user-requested set of columns and a particular point format

# Arguments
* `TPoint` : Type of `LasPoint` format to check column compatibility for
* `required_columns` : Set of columns requested by the user (if empty, use all columns included in the format `TPoint`)
* `xyz` : Spatial information used to apply scaling/offset factors to point positions
"""
function get_cols_and_extractors(::Type{TPoint}, required_columns::TTuple, xyz::SpatialInfo) where {TPoint <: LasPoint, TTuple}
    las_columns = if isnothing(required_columns) || isempty(required_columns)
        has_columns(TPoint)
    else
        filter(c -> c in required_columns, has_columns(TPoint))
    end
    extractors = map(c -> Extractor{c}(xyz), las_columns)
    return las_columns, extractors
end

"""
    $(TYPEDSIGNATURES)

Helper function that finds the names of user-defined point fields that have been requested by a user and group them together if they form arrays in the output data. 
Note according to spec that user-defined array field names must be of the form `col [0], col[1], ..., col[N]` where `N` is the dimension of the user field
"""
function get_user_fields_for_table(records::Vector{TRecord}, Names::Tuple, required_columns::TTuple) where {TRecord <: Union{ExtendedPointRecord, FullRecord}, TTuple}
    get_all_fields = isnothing(required_columns)
    user_fields = filter(field -> get_all_fields || get_base_field_name(field) ∈ required_columns, Names)
    raw_user_data = Dict{Symbol, Vector}(field => getproperty.(getproperty.(records, :user_fields), field) for field ∈ user_fields)
    user_field_map = get_user_field_map(user_fields)
    grouped_field_names = collect(keys(user_field_map))
    user_fields = filter(field -> get_all_fields || field ∈ required_columns, grouped_field_names)
    grouped_user_fields = group_user_fields(raw_user_data, user_field_map)
    return user_fields, grouped_user_fields
end

"""
    $(TYPEDSIGNATURES)

Helper function that maps a user field name to the set of user field names in the Extra Bytes VLRs that are entries for this field.
If a user field is a scalar, this will simply map `user_field => [user_field]`. If it is a vector, it will map `col => ["col [0]", "col [1]", ..., "col [N]"]`
"""
function get_user_field_map(user_fields::Union{Tuple, Vector})
    field_map = Dict{Symbol, Vector{Symbol}}()
    for field ∈ user_fields
        base_name = get_base_field_name(field)
        if base_name ∉ keys(field_map)
            field_map[base_name] = Symbol[]
        end
        push!(field_map[base_name], field)
    end
    # need to make sure we put the array entries back in the right order: "col [0]", "col [1]", etc.
    return Dict{Symbol, Vector{Symbol}}(base_name => sort(field_map[base_name]) for base_name ∈ keys(field_map))
end

"""
    $(TYPEDSIGNATURES)

Helper function that groups raw user field data into either a vector of scalars or vector of vectors

# Arguments
* `raw_user_data` : Maps the raw user field names (as they appear in the Extra Bytes VLRs, e.g. "col" for scalar or "col [n]" for entry in array) to their data in each point record
* `user_field_map` : Maps each user field base name to the collection of raw user field names composing it
"""
function group_user_fields(raw_user_data::Dict{Symbol, Vector}, user_field_map::Dict{Symbol, Vector{Symbol}})
    out = []
    for base_field ∈ keys(user_field_map)
        if length(user_field_map[base_field]) == 1
            push!(out, raw_user_data[base_field])
        else
            all_data = map(field -> raw_user_data[field], user_field_map[base_field])
            N = length(all_data)
            T = eltype(all_data[1])
            vals = map(i -> SVector{N, T}(getindex.(all_data, Ref(i))), eachindex(all_data[1]))
            push!(out, vals)
        end
    end
    return Tuple(out)
end

"""
    $(TYPEDSIGNATURES)

Convert the position units of some `pointcloud` data into metres based upon the coordinate units in the LAS file's `vlrs`.
Can override the unit conversion by manually specifying a unit to convert on the *XY*-plane, `convert_x_y_units`, and/or a unit to convert on the z-axis `convert_z_units` (missing if not overriding)
"""
function convert_units!(pointcloud::AbstractVector{<:NamedTuple}, vlrs::Vector{LasVariableLengthRecord}, convert_x_y_units::Union{Missing, String}, convert_z_units::Union{Missing, String})
    if :position ∈ columnnames(pointcloud)
        these_are_wkts = is_ogc_wkt_record.(vlrs)
        # we are not requesting unit conversion and there is no OGC WKT VLR
        if ismissing(convert_x_y_units) && ismissing(convert_z_units) && count(these_are_wkts) == 0
            return NO_CONVERSION
        else 
            @assert count(these_are_wkts) == 1 "Expected to find 1 OGC WKT VLR, instead found $(count(these_are_wkts))"
            ogc_wkt = get_data(vlrs[findfirst(these_are_wkts)])
            conversion = conversion_from_vlrs(ogc_wkt, convert_x_y_units = convert_x_y_units, convert_z_units = convert_z_units)
            if !ismissing(conversion) && any(conversion .!= 1.0)
                @info "Positions converted to meters using conversion $(conversion)"
                pointcloud = pointcloud.position .= map(p -> p .* conversion, pointcloud.position)
            end
            return conversion
        end
    end
    return NO_CONVERSION
end

"""
    $(TYPEDEF)

An iterator for reading point records
    
$(TYPEDFIELDS)
"""
struct ReadPointsIterator{TIO, TRecord}
    """IO channel to read point records from"""
    io::TIO

    """Number of points to read in total"""
    num_points::Integer
end

function Base.iterate(iter::ReadPointsIterator{TIO, TRecord}) where {TIO,TRecord}
    if iter.num_points == 0
        return nothing
    else
        return (read(iter.io, TRecord), 1)
    end
end

function Base.iterate(iter::ReadPointsIterator{TIO, TRecord}, n::Integer) where {TIO,TRecord}
    if n ≥ iter.num_points
        return nothing
    else
        return (read(iter.io, TRecord), n + 1)
    end
end


Base.eltype(::Type{ReadPointsIterator{TIO, TRecord}}) where {TIO,TRecord} = TRecord
Base.length(iter::ReadPointsIterator{TIO, TRecord}) where {TIO,TRecord} = iter.num_points

Base.IteratorSize(::Type{ReadPointsIterator{TIO, TRecord}}) where {TIO,TRecord} = Base.HasLength()
Base.IteratorEltype(::Type{ReadPointsIterator{TIO, TRecord}}) where {TIO,TRecord} = Base.HasEltype()
Base.isdone(iter::ReadPointsIterator{TIO, TRecord}) where {TIO, TRecord} = position(iter.io) ≥ (iter.num_points * byte_size(TRecord))
