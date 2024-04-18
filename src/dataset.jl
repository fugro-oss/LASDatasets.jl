"""
    $(TYPEDEF)

A wrapper around a LAS dataset. Contains point cloud data in tabular format as well as metadata and VLR's/EVLR's

$(TYPEDFIELDS)
"""
mutable struct LasDataset
    """The header from the LAS file the points were extracted from"""
    const header::LasHeader
    
    """LAS point cloud data stored in a Tabular format for convenience"""
    const pointcloud::Table

    """Additional user data assigned to each point that aren't standard LAS fields"""
    _user_data::Union{Missing, FlexTable}
    
    """Collection of Variable Length Records from the LAS file"""
    const vlrs::Vector{LasVariableLengthRecord}
    
    """Collection of Extended Variable Length Records from the LAS file"""
    const evlrs::Vector{LasVariableLengthRecord}

    """Extra user bytes packed between the Header block and the first VLR of the source LAS file"""
    const user_defined_bytes::Vector{UInt8}

    function LasDataset(header::LasHeader,
                        pointcloud::Table,
                        vlrs::Vector{<:LasVariableLengthRecord},
                        evlrs::Vector{<:LasVariableLengthRecord},
                        user_defined_bytes::Vector{UInt8})

        # do a few checks to make sure everything is consistent between the header and other data
        point_format_from_table = get_point_format(pointcloud)
        point_format_from_header = point_format(header)
        matching_formats = point_format_from_table == point_format_from_header
        # if the formats don't match directly, at least make sure all our table columns are the same as the header columns (so it can be a subset)
        cols_in_table_are_subset = all(has_columns(point_format_from_table) .∈ Ref(has_columns(point_format_from_header)))
        @assert matching_formats || cols_in_table_are_subset "Point format in header $(point_format_from_header) doesn't match point format in Table $(point_format_from_table)"
        
        num_points_in_table = length(pointcloud)
        num_points_in_header = number_of_points(header)
        @assert num_points_in_table == num_points_in_header "Number of points in header $(num_points_in_header) doesn't match number of points in table $(num_points_in_table)"

        num_vlrs = length(vlrs)
        num_vlrs_in_header = number_of_vlrs(header)
        @assert num_vlrs == num_vlrs_in_header "Number of VLR's in header $(num_vlrs_in_header) doesn't match number of VLR's supplied $(num_vlrs)"

        num_evlrs = length(evlrs)
        num_evlrs_in_header = number_of_evlrs(header)
        @assert num_evlrs == num_evlrs_in_header "Number of EVLR's in header $(num_evlrs_in_header) doesn't match number of EVLR's supplied $(num_evlrs)"

        # if points don't have an ID column assigned to them, add it in
        if :id ∉ columnnames(pointcloud)
            pointcloud = Table(pointcloud, id = collect(1:length(pointcloud)))
        end

        # need to split out our "standard" las columns from user-specific ones
        cols = collect(columnnames(pointcloud))
        these_are_las_cols = cols .∈ Ref(RECOGNISED_LAS_COLUMNS)
        las_cols = cols[these_are_las_cols]
        other_cols = cols[.!these_are_las_cols]
        las_pc = Table(NamedTuple{ (las_cols...,) }( (map(col -> getproperty(pointcloud, col), las_cols)...,) ))
        user_pc = isempty(other_cols) ? missing : FlexTable(NamedTuple{ (other_cols...,) }( (map(col -> getproperty(pointcloud, col), other_cols)...,) ))
        for col ∈ other_cols
            # account for potentially having an undocumented entry - in this case, don't add an ExtraBytes VLR
            if col != :undocumented_bytes
                col_type = eltype(getproperty(pointcloud, col))
                extra_bytes_vlrs = extract_vlr_type(vlrs, LAS_SPEC_USER_ID, ID_EXTRABYTES)
                extra_bytes_data = get_data.(extra_bytes_vlrs)
                matches_name = Symbol.(name.(extra_bytes_data)) .== col
                matches_name_idx = findfirst(matches_name)
                matches_type = data_type.(extra_bytes_data) .== col_type
                matches_both_idx = findfirst(matches_name .& matches_type)
                if !isnothing(matches_both_idx)
                    # if there's an ExtraBytes VLR with the same name and data type, we can skip
                    continue
                elseif !isnothing(matches_name_idx)
                    # if we find one with matching name (not type), we'll need to update the header record length to account for this new type
                    header.data_record_length -= sizeof(data_type(get_data(vlrs[matches_name_idx])))
                end
                # need to add an Extra Bytes VLR for this column
                extra_bytes = ExtraBytes(0x00, String(col), zero(col_type), zero(col_type), zero(col_type), zero(col_type), zero(col_type), "Custom Column $(col)")
                extra_bytes_vlr = LasVariableLengthRecord(LAS_SPEC_USER_ID, ID_EXTRABYTES, String(col), extra_bytes)
                push!(vlrs, extra_bytes_vlr)
                header.n_vlr += 1
                header.data_offset += sizeof(extra_bytes_vlr)
                header.data_record_length += sizeof(col_type)
            end
        end
        return new(header, las_pc, user_pc, Vector{LasVariableLengthRecord}(vlrs), Vector{LasVariableLengthRecord}(evlrs), user_defined_bytes)
    end
end

get_header(las::LasDataset) = las.header
get_vlrs(las::LasDataset) = las.vlrs
get_evlrs(las::LasDataset) = las.evlrs
get_user_defined_bytes(las::LasDataset) = las.user_defined_bytes

function get_pointcloud(las::LasDataset)
    if ismissing(las._user_data)
        return las.pointcloud
    else
        return Table(las.pointcloud, las._user_data)
    end
end

function Base.show(io::IO, las::LasDataset)
    println(io, "LAS Dataset")
    println(io, "\tNum Points: $(length(get_pointcloud(las)))")
    println(io, "\tPoint Format: $(point_format(get_header(las)))")
    println(io, "\tPoint Channels: $(columnnames(las.pointcloud))")
    if !ismissing(las._user_data)
        println(io, "\tUser Fields: $(columnnames(las._user_data))")
    end
    println(io, "\tVLR's: $(length(get_vlrs(las)))")
    println(io, "\tEVLR's: $(length(get_evlrs(las)))")
    println(io, "\tUser Bytes: $(length(get_user_defined_bytes(las)))")
end

function Base.:(==)(lasA::LasDataset, lasB::LasDataset)
    # need to individually check that the header, point cloud, (E)VLRs and user bytes are all the same
    headers_equal = get_header(lasA) == get_header(lasB)
    pcA = get_pointcloud(lasA)
    pcB = get_pointcloud(lasB)
    colsA = columnnames(pcA)
    colsB = columnnames(pcB)  
    pcs_equal = all([
        length(colsA) == length(colsB),
        length(pcA) == length(pcB),
        all(sort(collect(colsA)) .== sort(collect(colsB))),
        all(map(col -> all(isapprox.(getproperty(pcA, col), getproperty(pcB, col); atol = 1e-6)), colsA))
    ])
    vlrsA = get_vlrs(lasA)
    vlrsB = get_vlrs(lasB)
    vlrs_equal = all([
        length(vlrsA) == length(vlrsB),
        # account for fact that VLRS might be same but in different order
        all(map(vlr -> any(vlrsB .== Ref(vlr)), vlrsA)),
        all(map(vlr -> any(vlrsA .== Ref(vlr)), vlrsB)),
    ])
    evlrsA = get_evlrs(lasA)
    evlrsB = get_evlrs(lasB)
    evlrs_equal = all([
        length(evlrsA) == length(evlrsB),
        # account for fact that VLRS might be same but in different order
        all(indexin(evlrsA, evlrsB) .!= nothing),
        all(indexin(evlrsB, evlrsA) .!= nothing)
    ])
    user_bytes_equal = get_user_defined_bytes(lasA) == get_user_defined_bytes(lasB)
    return all([headers_equal, pcs_equal, vlrs_equal, evlrs_equal, user_bytes_equal])
end

"""
    $(TYPEDSIGNATURES)

Add a `vlr` into the set of VLRs in a LAS dataset `las`.
Note that this will modify the header content of `las`, including updating its LAS version to v1.4 if `vlr` is extended
"""
function add_vlr!(las::LasDataset, vlr::LasVariableLengthRecord)
    if is_extended(vlr) && isempty(get_evlrs(las))
        # evlrs only supported in LAS 1.4
        set_las_version!(get_header(las), v"1.4")
    end

    header = get_header(las)
    
    if is_extended(vlr)
        set_num_evlr!(header, number_of_evlrs(header) + 1)
        push!(get_evlrs(las), vlr)
        if number_of_evlrs(header) == 1
            # if this is our first EVLR, need to set the EVLR offset to point to the correct location
            header.evlr_start = point_data_offset(header) + (number_of_points(header) * point_record_length(header))
        end
    else
        set_num_vlr!(header, number_of_vlrs(header) + 1)
        push!(get_vlrs(las), vlr)
        # make sure to increase the point offset since we're cramming another VLR before the points
        header.data_offset += sizeof(vlr)
    end
end

"""
    $(TYPEDSIGNATURES)

Remove a `vlr` from set of VLRs in a LAS dataset `las`.
Note that this will modify the header content of `las`
"""
function remove_vlr!(las::LasDataset, vlr::LasVariableLengthRecord)
    header = get_header(las)
    if is_extended(vlr)
        set_num_evlr!(header, number_of_evlrs(header) - 1)
        evlrs = get_evlrs(las)
        matching_idx = findfirst(evlrs .== Ref(vlr))
        @assert !isnothing(matching_idx) "Couldn't find EVLR in LAS"
        deleteat!(evlrs, matching_idx)
        if isempty(evlrs)
            header.evlr_start = 0
        end
    else
        set_num_vlr!(header, number_of_vlrs(header) - 1)
        vlrs = get_vlrs(las)
        matching_idx = findfirst(vlrs .== Ref(vlr))
        @assert !isnothing(matching_idx) "Couldn't find VLR in LAS"
        deleteat!(vlrs, matching_idx)
        header.data_offset -= sizeof(vlr)
        @assert header.data_offset > 0 "Inconsistent data configuration! Got data offset of $(header.data_offset) after removing VLR"
    end
end

function set_superseded!(las::LasDataset, vlr::LasVariableLengthRecord)
    vlrs = is_extended(vlr) ? get_evlrs(las) : get_vlrs(las)
    matching_idx = findfirst(vlrs .== Ref(vlr))
    @assert !isnothing(matching_idx) "Couldn't find VLR in LAS"
    set_superseded!(vlrs[matching_idx])
end

"""
    $(TYPEDSIGNATURES)

Add a column with a `column` and set of `values` to a `las` dataset
"""
function add_column!(las::LasDataset, column::Symbol, values::AbstractVector{T}) where T
    @assert length(values) == length(las.pointcloud) "Column size $(length(values)) inconsistent with number of points $(length(las.pointcloud))"
    if ismissing(las._user_data)
        las._user_data = FlexTable(NamedTuple{ (column,) }( (values,) ))
    else
        # make sure if we're replacing a column we correctly update the header size
        if column ∈ columnnames(las._user_data)
            las.header.data_record_length -= sizeof(eltype(getproperty(las._user_data, column)))
        end
        Base.setproperty!(las._user_data, column, values)
    end
    las.header.data_record_length += sizeof(T)
    vlrs = get_vlrs(las)
    extra_bytes_vlrs = extract_vlr_type(vlrs, LAS_SPEC_USER_ID, ID_EXTRABYTES)
    matching_extra_bytes_vlr = findfirst(Symbol.(name.(get_data.(extra_bytes_vlrs))) .== column)
    if !isnothing(matching_extra_bytes_vlr)
        remove_vlr!(las, extra_bytes_vlrs[matching_extra_bytes_vlr])
    end
    extra_bytes = ExtraBytes(0x00, String(column), zero(T), zero(T), zero(T), zero(T), zero(T), "Custom Column $(column)")
    extra_bytes_vlr = LasVariableLengthRecord(LAS_SPEC_USER_ID, ID_EXTRABYTES, String(column), extra_bytes)
    add_vlr!(las, extra_bytes_vlr)
    nothing
end