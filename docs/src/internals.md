# Internals

## Data Consistency

When creating a `LasDataset` or writing a tabular point cloud out to a file, we need to make sure that the header information we provide is consistent with that of the point cloud and any *VLRs* and user bytes. Internally, this is done using the function `make_consistent_header!`, which compares a `LasHeader` and some *LAS* data and makes sure the header has the appropriate data offsets, flags and other metadata. This will, for example, make sure that the numbers of points, *VLRs* and *EVLRs* are consistent with the data we've provided, so your `LasDataset` is guaranteed to be consistent.

```@docs; canonical = false
LasDatasets.make_consistent_header!
LasDatasets.make_consistent_header
```

## Third Party Packages

This package relies heavily upon [PackedReadWrite.jl](https://github.com/EvertSchippers/PackedReadWrite.jl) to speed up the reading and writing of `LasPoint`s and some of our *VLRs*. 

We also use [BufferedStreams.jl](https://github.com/JuliaIO/BufferedStreams.jl) to drastically reduce I/O overhead.

## Point Records

As outlined in the [User Fields Section](./user_fields.md), in order to offer full support of "extra point data" in our *LAS* files, we treat *LAS* point records as having a point, extra user fields and a set of undocumented bytes. Internally, however, this is broken up into 4 separate classes each implementing the `LasRecord` abstract type. These correspond to each combination of a point with/without user fields/undocumented bytes.

```@docs; canonical = false
LasDatasets.LasRecord
LasDatasets.PointRecord
LasDatasets.ExtendedPointRecord
LasDatasets.UndocPointRecord
LasDatasets.FullRecord
```

This was done largely to increase performance of reading point records, since having one single type for point records would require more conditional checks to see if certain extra fields need to be read from a file which ends up congesting the read process. Instead, we use *Julia*'s multiple dispatch and define `Base.read` and `Base.write` methods for each record type and avoid these checks and also decrease the type inference time when reading these into a vector.

## Reading Points Iterator

When reading, we also wrap our IO stream in an iterator, `LasDatasets.ReadPointsIterator`, to reduce the overhead of reading point records sequentially. It turns out that calling `map(r -> r, iter)` where `iter` is a `LasDatasets.ReadPointsIterator` is much faster than calling `map(_ -> read(io, TRecord), 1:num_points)`

```@docs; canonical = false
LasDatasets.ReadPointsIterator
```

## Writing Optimisations
Typically, *Julia* is slower at performing multiple consecutive smaller writes to an IO channel than one much larger write. For this reason, when writing point records to a *LAS* file, we first construct a vector of bytes from the records and then write that whole vector to the file. This is possible since for each point record we know:
* How many bytes the point format is,
* How many user fields in this record and their data size in bytes and
* How many undocumented bytes there are.

This is done using `LasDatasets.get_record_bytes`, which takes a collection of *LAS* records and writes each *LAS* field, user field and extra bytes collection into its correct location in the final byte vector. 

In order to do this, we need to frequently access each field in a (potentially huge) list of records, which in normal circumstances is slow. We instead first pass our records into a `StructVector` using [StructArrays.jl](https://github.com/JuliaArrays/StructArrays.jl) which vastly increases the speed at which we can access these fields and broadcast over them.

```@docs; canonical = false
LasDatasets.get_record_bytes
```

## Automatic Support for User Fields

In order for the system to automatically handle a user supplying their own custom fields in a point cloud table, we make some checks on field types and have processes in place that ensure each column has an `ExtraBytes` *VLR* associated to it.

Firstly, the *LAS* 1.4 spec officially supports the following data types directly: `UInt8`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`, `UInt64`, `Int64`, `Float32` and `Float64`

This means that every `ExtraBytes` *VLR* **must** have a data type among these values (note that vectors are not directly supported). *LasDatasets.jl* supports static vectors (static sizing is essential) as user fields as well by internally separating out vector components and adding an `ExtraBytes` *VLR* for each component following the naming convention in the spec. That is, for a user field with `N` entries, the individual component names that are documented in the *VLRs* are "col [0]", "col [1]", ..., "col [N - 1]".

When a user passes a custom field to the system, it will firstly check that the data type for this field is either one of the above types or an `SVector` of one. If it is a vector, it will construct a list of the component element field names as above. Then, it will extract all `ExtraBytes` *VLRs* and check if any of them have matching names and update them iff they exist so their data type matches the new type supplied. If these are new fields, a new `ExtraBytes` *VLR* will be added per field name. Finally, the header is updated to reflect the new number of *VLRs*, the new data offsets and the new point record lengths.