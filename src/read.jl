function load_header(file_name::AbstractString)
    header = open_las(file_name, "r") do io
        read(io, LasHeader)
    end
    return header
end

load_header(io::IO) = read(seek(io, 0), LasHeader)

function load_vlrs(io::IO, header::LasHeader)
    vlr_start = header_size(header)
    seek(io, vlr_start)
    num_vlrs = number_of_vlrs(header)
    map(_ -> read(io, LasVariableLengthRecord), 1:num_vlrs)
end

function load_vlrs(file_name::AbstractString, header::LasHeader)
    vlrs = open_las(file_name, "r") do io
        load_vlrs(io, header)
    end
    return vlrs
end

function load_vlrs(file_name::AbstractString)
    vlrs = open_las(file_name, "r") do io
            header = read(io, LasHeader)
            load_vlrs(io, header)
    end
    return vlrs
end