# Points

*LAS* 1.4 supports 11 point formats which are directly represented by *Julia* structs. They each implement the abstract type `LasPoint{N}`, which is parametrised by the point format ID `N`. Each point format thus has a concrete struct of the form `LasPointN <: LasPoint{N}` that implements the abstract type for that format ID. 

```@docs; canonical = false
LasPoint0
LasPoint1
LasPoint2
LasPoint3
LasPoint4
LasPoint5
LasPoint6
LasPoint7
LasPoint8
LasPoint9
LasPoint10
```

You can get the concrete point format struct and the point format ID for a given `LasPoint` type with the following helper functions:

```@docs; canonical = false
LAS.get_point_format
LAS.get_point_format_id
```