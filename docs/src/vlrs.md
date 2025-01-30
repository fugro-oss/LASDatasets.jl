# Variable Length Records

*Variable Length Records* are useful packets of data that one can include between the header block and start of the point records in a *LAS* file. The *LAS* 1.4 spec also allows for larger data payloads to be stored as *Extended Variable Length Records*, which are stored at the end of the file after the point records. The difference between these is that regular *VLRs* can only have a payload up to 2^16 bytes whereas *EVLRs* can have a payload up to 2^64.

All types of *VLRs* (regular and extended) are wrapped inside a `LasVariableLengthRecord` struct, which holds the data payload as well as the relevant *VLR* IDs and metadata. Each `LasVariableLengthRecord` is parametrised by the type of data in its payload which makes *LASDatasets.jl* able to handle parsing each *VLR* to/from a native *Julia* struct automatically.

```@docs; canonical = false
LasVariableLengthRecord
```

## Coordinate Reference System VLRs

The *LAS* 1.4 spec provides definitions for storing coordinate reference system details as *VLRs*. These are implemented as their own structs so they can be wrapped inside `LasVariableLengthRecord`s. These are split into two flavours: *WKT*, which uses the OpenGIS
coordinate transformation service implementation specification [here](https://www.opengeospatial.org/standards/ct), and *GeoTiff*, which are included for legacy support for specs 1.1-1.3 (and are incompatible with *LAS* point formats 6-10).

### WKT

*LASDatasets.jl* supports the *OGC Coordinate System WKT Record*, which is handled by the struct `OGC_WKT`. Currently we don't support *OGC Math Transform WKT*, however this could be supported in a future release.

```@docs; canonical = false
OGC_WKT
```

One benefit of using the *OGC WKT* is that you can specify what units of measurement are used for your point coordinates both in the *XY* plane and along the *Z* axis. When reading a *LAS* file, the system can detect if an *OGC WKT* is present and will, if requested by the user, convert the point coordinates to metres.

### GeoTiff

*GeoTiff* *VLRs* are supported for legacy versions and also have their own *Julia* struct, which are given below. 

```@docs; canonical = false
GeoKeys
GeoDoubleParamsTag
GeoAsciiParamsTag
```

## Other Specification-Defined VLRs

The *LAS* 1.4 spec also includes several other recognised *VLRs* that are automatically supported in *LASDatasets.jl*. 

### Classification Lookup

*LAS* 1.4 allows you to specify classification labels 0-255 for your point formats 6-10, where labels 0-22 having specific classes associated with them, classes 23-63 being reserved and classes 64-255 being user-definable. To give context to what your classes mean, you can add a Classification Lookup *VLR* into your *LAS* file, which is just a collection of classification labels paired with a string description. In *LASDatasets.jl*, this is handled as a `ClassificationLookup`:

```@docs; canonical = false
ClassificationLookup
```

As an example, you can add a Classification Lookup *VLR* to your *LAS* file as follows:

```julia
pc = Table(position = rand(SVector{3, Float64}, 100), classification = rand((65, 100), 100))
# class 65 represents mailboxes, 100 represents street signs
lookup = ClassificationLookup(65 => "Mailboxes", 100 => "Street signs")
# make sure you set the right VLR IDs
vlrs = [LasVariableLengthRecord("LASF_Spec", 0, "Classification Lookup", lookup)]
save_las("pc.las", pc; vlrs = vlrs)
```

You can then read the *LAS* data and extract the classification lookup:

```julia
las = load_las("pc.las")
# look for the classification lookup VLR by checking for its user and record IDs
lookup_vlr = extract_vlr_type(get_vlrs(las), "LASF_Spec", 0)
lookup = get_data(lookup_vlr)
```

### Text Area Descriptions

You can add a description for your dataset using a `TextAreaDescription` data type

```@docs; canonical = false
TextAreaDescription
```

Using the dataset `las` above, we can add a description as follows (and save/read it as we did above). Note you can also repeat the way the Classification Lookup was saved above too.

```julia
description = TextAreaDescription("This is an example LAS file and has no specific meaning")
add_vlr!(las, LasVariableLengthRecord("LASF_Spec", 3, "Text Area Description", description))
```

### Extra Bytes

Extra Bytes *VLRs* are a type of *VLR* that documents any user fields that have been added to point records in your *LAS* data. You can find an in-depth explanation of how to save/load user defined fields to your points [here](./user_fields.md). 

The Extra Bytes *VLRs* are represented by the `ExtraBytes` struct, and have a few methods to get some information from them. Note that currrently *LASDatasets.jl* only supports automatically detecting and writing the user field name, data type and description to the *VLR* based on input point data. Support for other fields such as the min/max range, scale/offset factors, etc. may become available in future releases. You can, however, still manually specify these if you choose.

```@docs; canonical = false
ExtraBytes
LASDatasets.name
LASDatasets.data_type
```

### Waveform Data

Currently *LASDatasets.jl* doesn't have fully extensive support for waveform data and flags, but this will likely be included in future releases. We do, however, support writing waveform packet descriptions as *VLRs* with the `WaveformPacketDescriptor`. 

```@docs; canonical = false
WaveformPacketDescriptor
```

## Custom VLRs

As well as the *VLR* record types mentioned above, you can write your own *Julia*-native structs as *VLRs* quite easily using *LASDatasets.jl*. By default, *LASDatasets.jl* will just read the raw bytes for your *VLRs*, so there are a couple of steps to enable correct *VLR* parsing.

Firstly, you need to define methods to read and write your data type. For writing, this just means overloading `Base.write` for your type.

Reading works a little differently. Since each *VLR* has a "record length after header", the system knows how many bytes each record needs. If your data type has statically-sized fields (like numbers or static arrays), you already know how many bytes you're reading (and this needs to be reflected in a `Base.sizeof` method for your type). You'll need to overload the function `LASDatasets.read_vlr_data` for your data type, which accepts the number of bytes to read alongside your type. This allows you to read non-static types for fields as well as static ones.

```@docs; canonical = false
read_vlr_data
```

As an example, you could have

```julia
struct MyType
    name::String

    value::Float64
end

# important to know how many bytes your record will take up
Base.sizeof(x::MyType) = Base.sizeof(x.name) + 8

function LASDatasets.read_vlr_data(io::IO, ::Type{MyType}, nb::Integer)
    @assert nb ≥ 8 "Not enough bytes to read data of type MyType!"
    # the name will depend on how many bytes we've been told to read
    name = LASDatasets.readstring(io, nb - 8)
    value = read(io, Float64)
    return MyType(name, value)
end

function Base.write(io::IO, x::MyType)
    write(io, x.name)
    write(io, x.value)
end
```

Finally, the system needs some way to know what data type to read for the *VLR* for a specific user ID and record ID, otherwise it will just read the raw bytes back to you. To register the "official" IDs to use, you can use the macro `@register_vlr_type`:

```@docs; canonical = false
@register_vlr_type
```

So in our example, we can tell the system that records containing data of type `MyType` will always have a user ID "My Custom Records" and record IDs 1-100:

```julia
@register_vlr_type MyType "My Custom Records" collect(1:100)
```

And now we can save our `MyType` *VLRs* into a *LAS* file in the same way as we did above for the register *VLR* types. Note that you can use the function `extract_vlr_type` on your collection of *VLRs* to pull out the *VLR* with a specific user ID and record ID. 

```@docs; canonical = false
extract_vlr_type
```