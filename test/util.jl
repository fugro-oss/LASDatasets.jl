@testset "Utils" begin
    # make sure we can read and write strings properly
    io = IOBuffer()
    
    # trying to write a string that's over our num bytes limit should fail
    @test_throws AssertionError LasDatasets.writestring(io, "imtoolong", 1)
    
    # if we pick the num bytes to be the same length as the string, should get the same string back
    LasDatasets.writestring(io, "string", 6)
    seek(io, 0)
    str_out = LasDatasets.readstring(io, 6)
    @test str_out == "string"
    
    # if it's a bit too short, we should get some padding
    take!(io)
    LasDatasets.writestring(io, "string", 10)
    seek(io, 0)
    bytes = read(io, 10)
    @test String(bytes) == "string\0\0\0\0"
    # but we should only read out the actual string when using readstring
    seek(io, 0)
    str_out = LasDatasets.readstring(io, 10)
    @test str_out == "string"

    # if we write an empty string then we should get an empty string
    take!(io)
    LasDatasets.writestring(io, "", 5)
    seek(io, 0)
    @test LasDatasets.readstring(io, 5) == ""
end