@testset "Utils" begin
    # make sure we can read and write strings properly
    io = IOBuffer()
    
    # trying to write a string that's over our num bytes limit should fail
    @test_throws AssertionError LASDatasets.writestring(io, "imtoolong", 1)
    
    # if we pick the num bytes to be the same length as the string, should get the same string back
    LASDatasets.writestring(io, "string", 6)
    seek(io, 0)
    str_out = LASDatasets.readstring(io, 6)
    @test str_out == "string"
    
    # if it's a bit too short, we should get some padding
    take!(io)
    LASDatasets.writestring(io, "string", 10)
    seek(io, 0)
    bytes = read(io, 10)
    @test String(bytes) == "string\0\0\0\0"
    # but we should only read out the actual string when using readstring
    seek(io, 0)
    str_out = LASDatasets.readstring(io, 10)
    @test str_out == "string"

    # if we write an empty string then we should get an empty string
    take!(io)
    LASDatasets.writestring(io, "", 5)
    seek(io, 0)
    @test LASDatasets.readstring(io, 5) == ""

    # test with special characters whose ASCII encoding is > 0x80, meaning their number of "code units" will be 2, not one
    # see here for more details: https://docs.julialang.org/en/v1/manual/strings/#Unicode-and-UTF-8
    str = "aβcd"
    take!(io)
    LASDatasets.writestring(io, str, 5)
    seek(io, 0)
    bytes = read(io)
    @test String(bytes)== str

    # and we should still get the correct buffer if we ask for more bytes
    take!(io)
    LASDatasets.writestring(io, str, 7)
    seek(io, 0)
    bytes = read(io)
    @test String(bytes) == "$(str)\0\0"
end