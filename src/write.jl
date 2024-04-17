"""
    save_las(file_name, pointcloud)
Saves a pointcloud (TypedTable) to LAS or LAZ. Methods figures out itself which LAS version and Point format to use.
For more control over LAS version and point formats, use `write_las`.
"""
function save_las(file_name::AbstractString, pointcloud::AbstractVector{<:NamedTuple}; 
                        vlrs::Vector{<:LasVariableLengthRecord} = Vector{LasVariableLengthRecord}(),
                        evlrs::Vector{<:LasVariableLengthRecord} = Vector{LasVariableLengthRecord}(),
                        user_defined_bytes::Vector{UInt8} = Vector{UInt8}(),
                        scale::Real = POINT_SCALE,
                        kwargs...)
    open_func = get_open_func(file_name)
    open_func(file_name, "w") do io
        write_las(io, pointcloud, vlrs, evlrs, user_defined_bytes, scale)
    end
end

function save_las(file_name::AbstractString, las::LasContent)
    open_func = get_open_func(file_name)
    open_func(file_name, "w") do io
        write_las(io, las)
    end
end

function save_las(file_name::AbstractString, 
                    header::LasHeader, 
                    point_records::Vector{TRecord}, 
                    vlrs::Vector{<:LasVariableLengthRecord} = Vector{LasVariableLengthRecord}(), 
                    evlrs::Vector{<:LasVariableLengthRecord} = Vector{LasVariableLengthRecord}(), 
                    user_defined_bytes::Vector{UInt8},
                    scale::Real) where {TRecord <: LasRecord}
    open_func = get_open_func(file_name)
    open_func(file_name, "w") do io
        write_las(io, header, point_records, vlrs, evlrs, user_defined_bytes, scale)
    end
end

function write_las(io::IO, pointcloud::AbstractVector{<:NamedTuple},
                    vlrs::Vector{<:LasVariableLengthRecord}, 
                    evlrs::Vector{<:LasVariableLengthRecord}, 
                    user_defined_bytes::Vector{UInt8},
                    scale::Real)
    point_format = get_point_format(pointcloud)
    write_las(io, pointcloud, point_format, vlrs, evlrs, user_defined_bytes, scale)
end


"""
    write_las(io::IO, ::Type{TVersion}, pointformat::Type{TPoint}, pointcloud::TData, vlrs::Vector{<:LasVariableLengthRecord}, spatial_info::SpatialInfo) where {TVersion <: LasVersion, TPoint, TData}
Uses `laspoint(TPoint, item::eltype(pointcloud), spatial_info::SpatialInfo)` to transform your data into `TPoint` items, which must be `LasPoint`s.
For now, make sure yourself you pick the correct LasVersion that supports the point format you chose.
"""
function write_las(io::IO, pointcloud::AbstractVector{<:NamedTuple}, 
                    point_format::Type{TPoint},
                    vlrs::Vector{<:LasVariableLengthRecord}, 
                    evlrs::Vector{<:LasVariableLengthRecord}, 
                    user_defined_bytes::Vector{UInt8},
                    scale::Real) where {TPoint}
    header = make_consistent_header(pointcloud, point_format, vlrs, evlrs, scale)
    write_las(io, LasContent(header, pointcloud, vlrs, evlrs, user_defined_bytes))
end

function write_las(io::IO, las::LasContent)
    header = get_header(las)

    pc = get_pointcloud(las)
    write(io, header)

    for vlr ∈ get_vlrs(las)
        write(io, vlr)
    end

    write(io, get_user_defined_bytes(las))

    this_point_format = point_format(header)
    xyz = spatial_info(header)

    user_fields = ismissing(las._user_data) ? () : columnnames(las._user_data)

    # packing points into a StructVector makes operations where you have to access per-point fields many times like in get_record_bytes below faster
    las_records = StructVector(las_record.(this_point_format, pc, Ref(xyz), Ref(user_fields)); unwrap = t -> (t <: LasPoint) || (t <: UserFields))
    byte_vector = get_record_bytes(las_records)
    write(io, byte_vector)

    for evlr ∈ get_evlrs(las)
        write(io, evlr)
    end

    return nothing
end

function make_consistent_header(pointcloud::AbstractVector{<:NamedTuple}, 
                                point_format::Type{TPoint},
                                vlrs::Vector{<:LasVariableLengthRecord}, 
                                evlrs::Vector{<:LasVariableLengthRecord},
                                scale::Real) where {TPoint <: LasPoint}
    version = lasversion_for_point(point_format)
    header_size = get_header_size_from_version(version)
    vlr_size = isempty(vlrs) ? 0 : sum(sizeof.(vlrs))
    point_data_offset = header_size + vlr_size

    spatial_info = get_spatial_info(pointcloud; scale = scale)

    header = LasHeader(; 
        las_version = version, 
        data_format_id = UInt8(get_point_format_id(point_format)), 
        data_record_length = UInt16(byte_size(point_format)),
        data_offset = UInt32(point_data_offset),
        n_vlr = UInt32(length(vlrs)),
        spatial_info = spatial_info,
    )

    set_point_record_count!(header, length(pointcloud))
    if !isempty(evlrs)
        set_num_evlr!(header, length(evlrs))
    end

    returns = haskey(pointcloud, :returnnumber) ? pointcloud.returnnumber : ones(Int, length(pointcloud))
    points_per_return = ntuple(r -> count(returns .== r), num_return_channels(header))
    set_number_of_points_by_return!(header, points_per_return)

    ogc_wkt_records = is_ogc_wkt_record.(vlrs)
    @assert count(ogc_wkt_records) ≤ 1 "Can't set more than 1 OGC WKT Transform in VLR's!"

    if any(ogc_wkt_records)
        set_wkt_bit!(header)
    end

    return header
end

function get_record_bytes(records::StructVector{TRecord}) where {TRecord <: LasRecord}
    point_format = get_point_format(TRecord)
    point_fields = collect(fieldnames(point_format))
    bytes_per_point_field = sizeof.(fieldtypes(point_format))
    user_field_bytes = get_num_user_field_bytes(TRecord)
    undoc_bytes = get_num_undocumented_bytes(TRecord)
    
    bytes_per_record = sum(bytes_per_point_field) + user_field_bytes + undoc_bytes

    total_num_bytes = length(records) * bytes_per_record
    whole_byte_vec = Vector{UInt8}(undef, total_num_bytes)
    byte_offset = 0
    lazy = LazyRows(records)
    field_idxs = Dict()
    for (i, field) ∈ enumerate(point_fields)
        field_byte_vec = reinterpret(UInt8, getproperty(lazy.point, field))
        if bytes_per_point_field[i] ∉ keys(field_idxs)
            field_idxs[bytes_per_point_field[i]] = reduce(vcat, map(j -> (0:bytes_per_point_field[i] - 1) .+ j, 1:bytes_per_record:total_num_bytes))
        end
        this_field_idxs = byte_offset > 0 ? field_idxs[bytes_per_point_field[i]] .+ byte_offset : field_idxs[bytes_per_point_field[i]]
        view(whole_byte_vec, this_field_idxs) .= field_byte_vec
        byte_offset += bytes_per_point_field[i]
    end

    if user_field_bytes > 0
        user_field_types = get_user_field_types(TRecord)
        bytes_per_user_field = sizeof.(user_field_types)
        for (i, user_field) ∈ enumerate(get_user_field_names(TRecord))
            field_byte_vec = reinterpret(UInt8, getproperty(lazy.user_fields, user_field))
            if bytes_per_user_field[i] ∉ keys(field_idxs)
                field_idxs[bytes_per_user_field[i]] = reduce(vcat, map(j -> (0:bytes_per_user_field[i] - 1) .+ j, 1:bytes_per_record:total_num_bytes))
            end
            this_field_idxs = field_idxs[bytes_per_user_field[i]] .+ byte_offset
            view(whole_byte_vec, this_field_idxs) .= field_byte_vec
            byte_offset += bytes_per_user_field[i]
        end
    end

    if undoc_bytes > 0
        undoc_idxs = reduce(vcat, map(j -> (0:N - 1) .+ j, (byte_offset + 1):bytes_per_record:total_num_bytes))
        view(whole_byte_vec, undoc_idxs) .= map(u -> Vector(u), Base.getproperty(records, :undocumented_bytes))
    end
    
    return whole_byte_vec
end