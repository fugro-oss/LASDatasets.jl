"""
    $(TYPEDSIGNATURES)

Saves a pointcloud to LAS or LAZ. The appropriate LAS version and point format is inferred from the contents of your point cloud

# Arguments
* `file_name` : Name of the LAS file to save the data into
* `pointcloud` : Point cloud data in a tabular format

### Keyword Arguments
* `vlrs` : Collection of Variable Length Records to write to the LAS file, default `LasVariableLengthRecord[]`
* `evlrs` : Collection of Extended Variable Length Records to write to the LAS file, default `LasVariableLengthRecord[]`
* `user_defined_bytes` : Any user-defined bytes to write in between the VLRs and point records, default `UInt8[]`
* `scale` : Scaling factor applied to points on writing, default `LAS.POINT_SCALE`
* `compressed` : Whether or not data is to be written to a compressed .laz file, default false

---
$(METHODLIST)
"""
function save_las(file_name::AbstractString, pointcloud::AbstractVector{<:NamedTuple}; 
                        vlrs::Vector{<:LasVariableLengthRecord} = LasVariableLengthRecord[], 
                        evlrs::Vector{<:LasVariableLengthRecord} = LasVariableLengthRecord[], 
                        user_defined_bytes::Vector{UInt8} = UInt8[],
                        scale::Real = POINT_SCALE,
                        kwargs...)
    open_func = get_open_func(file_name)
    open_func(file_name, "w") do io
        write_las(io, pointcloud, vlrs, evlrs, user_defined_bytes, scale, is_laz(file_name))
    end
end

function save_las(file_name::AbstractString, las::LasDataset)
    open_func = get_open_func(file_name)
    open_func(file_name, "w") do io
        write_las(io, las, is_laz(file_name))
    end
end

function save_las(file_name::AbstractString, 
                    header::LasHeader, 
                    point_records::Vector{TRecord}, 
                    vlrs::Vector{<:LasVariableLengthRecord} = LasVariableLengthRecord[], 
                    evlrs::Vector{<:LasVariableLengthRecord} = LasVariableLengthRecord[], 
                    user_defined_bytes::Vector{UInt8} = UInt8[],
                    scale::Real = POINT_SCALE) where {TRecord <: LasRecord}
    open_func = get_open_func(file_name)
    open_func(file_name, "w") do io
        write_las(io, header, point_records, vlrs, evlrs, user_defined_bytes, scale, is_laz(file_name))
    end
end

function write_las(io::IO, pointcloud::AbstractVector{<:NamedTuple},
                    vlrs::Vector{<:LasVariableLengthRecord} = LasVariableLengthRecord[], 
                    evlrs::Vector{<:LasVariableLengthRecord} = LasVariableLengthRecord[], 
                    user_defined_bytes::Vector{UInt8} = UInt8[],
                    scale::Real = POINT_SCALE,
                    compressed::Bool = false)
    point_format = get_point_format(pointcloud)
    write_las(io, pointcloud, point_format, vlrs, evlrs, user_defined_bytes, scale, compressed)
end


"""
    $(TYPEDSIGNATURES)

Write a pointcloud and additional VLR's and user-defined bytes to an IO stream in a LAS format

# Arguments
* `io` : IO channel to write the data to
* `pointcloud` : Pointcloud data in a tabular format to write
* `vlrs` : Collection of Variable Length Records to write to `io`
* `evlrs` : Collection of Extended Variable Length Records to write to `io`
* `user_defined_bytes` : Any user-defined bytes to write in between the VLRs and point records
* `scale` : Scaling factor applied to points on writing
* `compressed` : Whether or not data is to be written to a compressed .laz file, default false
"""
function write_las(io::IO, pointcloud::AbstractVector{<:NamedTuple}, 
                    point_format::Type{TPoint},
                    vlrs::Vector{<:LasVariableLengthRecord}, 
                    evlrs::Vector{<:LasVariableLengthRecord}, 
                    user_defined_bytes::Vector{UInt8},
                    scale::Real,
                    compressed::Bool = false) where {TPoint}
    # automatically construct a header that's consistent with the data and point format we've supplied
    header = make_consistent_header(pointcloud, point_format, vlrs, evlrs, user_defined_bytes, scale)
    write_las(io, LasDataset(header, pointcloud, vlrs, evlrs, user_defined_bytes), compressed)
end

function write_las(io::IO, las::LasDataset, compressed::Bool = false)
    header = get_header(las)
    vlrs = get_vlrs(las)
    
    pc = get_pointcloud(las)

    this_point_format = point_format(header)
    xyz = spatial_info(header)

    user_fields = ismissing(las._user_data) ? () : filter(c -> c != :undocumented_bytes, columnnames(las._user_data))

    # LASzip doesn't support extra bytes :(
    if compressed && !isempty(user_fields)
        # need to make copies here so we don't permanently modify the LAS dataset
        header = deepcopy(get_header(las))
        vlrs = deepcopy(get_vlrs(las))
        @warn "Can't compress custom user fields into LAZ! Ignoring user fields and extra bytes VLRs..."
        user_fields = ()
        # find indices of existing extra bytes VLRs
        extra_bytes_idxs = findall(vlr -> (get_user_id(vlr) == LAS_SPEC_USER_ID) && (get_record_id(vlr) == ID_EXTRABYTES), vlrs)
        if !isempty(extra_bytes_idxs)
            @assert length(extra_bytes_idxs) == 1 "Found $(length(extra_bytes_idxs)) Extra Bytes VLRs when we should only have 1"
            extra_bytes_vlr = vlrs[extra_bytes_idxs[1]]
            # need to adjust the data record length in the header to remove these extra bytes
            for extra_bytes ∈ get_extra_bytes(get_data(extra_bytes_vlr))
                header.data_record_length -= sizeof(data_type(extra_bytes))
            end
            # make sure we remove the extra bytes vlrs and adjust the header info
            header.n_vlr -= 1
            header.data_offset -= sizeof(extra_bytes_vlr)
            deleteat!(vlrs, extra_bytes_idxs)
        end
    end

    write(io, header)

    for vlr ∈ vlrs
        write(io, vlr)
    end

    write(io, get_user_defined_bytes(las))

    undoc_bytes = :undocumented_bytes ∈ columnnames(pc) ? pc.undocumented_bytes : fill(SVector{0, UInt8}(), length(pc))

    # packing points into a StructVector makes operations where you have to access per-point fields many times like in get_record_bytes below faster
    las_records = StructVector(las_record.(this_point_format, pc, Ref(xyz), undoc_bytes, Ref(user_fields)); unwrap = t -> (t <: LasPoint) || (t <: UserFields))
    byte_vector = get_record_bytes(las_records)
    write(io, byte_vector)

    for evlr ∈ get_evlrs(las)
        write(io, evlr)
    end

    return nothing
end

"""
    $(TYPEDSIGNATURES)

Construct an array of bytes that correctly encodes the information stored in a set of LAS `records` according to the spec
"""
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
        undoc_idxs = reduce(vcat, map(j -> (0:undoc_bytes - 1) .+ j, (byte_offset + 1):bytes_per_record:total_num_bytes))
        view(whole_byte_vec, undoc_idxs) .= reduce(vcat, map(u -> Vector(u), Base.getproperty(records, :undoc_bytes)))
    end
    
    return whole_byte_vec
end