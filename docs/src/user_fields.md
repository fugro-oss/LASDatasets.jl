# User-Defined Point Fields

In a *LAS* file, the header specifies a data record length, which is the number of bytes used per point record in the file. Note that this number could be larger than the minimal number of bytes needed to store the point format, and if this is the case, the point records will have "extra bytes" associated with them. The *LAS* 1.4 spec introduces an *Extra Bytes VLR*, which documents extra fields (which we will refer to as "user fields") associated to each point record with their name and data type, amongst other information. Note that in legacy versions, you could also store these "extra bytes" for point records, but there is no way to infer what type and what field names they have, so they are saved in the record as "Undocumented Bytes".

You can save user fields in your point cloud quite easily by including them as columns in your point cloud table. For example, you can save the user field "thing" along with your points and their classifications as follows:

```julia
pc = Table(position = rand(SVector{3, Float64}, 10), classification = rand(UIn8, 10), thing = rand(10))
save_las("my_pc.las", pc)
```

Under the hood, *LAS.jl* will automatically create the appropriate header fields for data record lengths etc. and will also create the appropriate Extra Bytes *VLRs* and save them in your *LAS* file. 

You can also add user fields to your *LAS* datasets as you go by calling `add_column!` with your new data and column name:

```julia
add_column!(las, :thing, rand(10))
```

This will add the user field "thing" to your dataset `las` and append the appropriate Extra Bytes *VLRs* to it. 

Reading user fields from *LAS* files is just as easy, since you can simply specify the desired user fields in your requested columns, e.g.

```julia
las = load_las("my_pc.las", [:position, :classification, :thing])
```

Note that user fields can also be vectors of static vectors, and once again *LAS.jl* will automatically save the appropriate Extra Bytes *VLRs* for you so you can specify them as you would any other user field:

```julia
using StaticArrays
pc = Table(position = rand(SVector{3, Float64}, 10), classification = rand(UIn8, 10), thing = rand(SVector{3, Float64}, 10))
save_las("my_pc.las", pc)
las = load_las("my_pc.las", [:position, :classification, :thing])
```