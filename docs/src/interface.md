# High-Level Interface

*LASDatasets.jl* provides a number of high-level functions to easily manipulate your *LAS* data. 

## *LAS* Datasets

A `LasDataset` is a wrapper around data from a *LAS* file that acts as an interface to read, write and modify your *LAS* data. In general, a *LAS* file will have the following contents:
* File Header: contains metadata about the file contents and byte layout
* *VLRs*: Variable length records of data that appear before the point records
* User-defined bytes: Additional bytes included after the last *VLR* and before the first point record
* *LAS* point records: data assigned to each point in the point cloud (following a specific format specified in the header)
* *EVLRs* : Extended *VLRs* that come after the point records (allows larger data payloads)

These are contained in a `LasDataset` as follows
```@docs; canonical = false
LasDataset
```

You can query the contents of your `LasDataset` by using the following functions:
```@docs; canonical = false
get_header
get_pointcloud
get_vlrs
get_evlrs
get_user_defined_bytes
```

## Reading
To read the entire contents of a *LAS* or *LAZ* file, you can use the `load_las` function. This returns a `LasDataset` with all the properties listed above. You also have the option of only loading certain point fields.

```julia
# read the full dataset
las = load_las("example.las")

# only extract position and classification
las = load_las("example.las", [:position, :classification])
```

Note that when reading data, the position units for your points are automatically converted to metres provided they are specified correctly in an *OGC Coordinate System WKT* string. If not, you can still manually specify what units you would like to convert from (note that they must match the unit naming convention given by *OGC WKTs*), e.g.

```julia
las = load_las("example.las"; convert_x_y_units = "us-ft")
```

```@docs; canonical = false
load_las
```

You can also choose to just load the points themselves (in tabular format), header or *VLRs* rather than the whole datsset by using the following functions:
```@docs; canonical = false
load_pointcloud
load_header
load_vlrs
```

## Writing
You can write the contents of your `LasDataset` to a file by using the `save_las` function. Note that this takes either a `LasDataset` on its own or a tabular point cloud with *(E)VLRs* and user-defined bytes supplied separately.

```@docs; canonical = false
save_las
```

For example, if you have the whole dataset:
```julia
save_las("my_las.las", las)
```

Alternatively, if you just have the point cloud data as a Table:
```julia
using StaticArrays
using TypedTables

pc = Table(position = rand(SVector{3, Float64}, 10), classification = rand(UIn8, 10))
save_las("my_las.las", pc)
```

Note that when you supply just the point cloud outside of a `LasDataset`, *LASDatasets.jl* will automatically construct the appropriate header for you so you don't need to worry about the specifics of appropriate point formats etc. 

## Modifying LAS Contents
You can modify point fields in your `LasDataset` by adding new columns or merging in values from an existing vector.

```@docs; canonical = false
add_column!
merge_column!
```

You can also add or remove *(E)VLRs* using the following functions, and set an existing *(E)VLR* as *superseded* if it's an old copy of a record.

```@docs; canonical = false
add_vlr!
remove_vlr!
set_superseded!
```