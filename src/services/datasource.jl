module Datasource

using ...SimpleTasks.Types

export get, put

"""
    get(datasource::DatasourceService, key::AbstractString; force::Bool=false)

Returns an IO reading the value in the datasource for the given key. Optionally
allow skipping any cached values.
"""
function get(datasource::DatasourceService, key::AbstractString;
        override_cache::Bool=false)
    error("get is not implemented for $datasource")
end

"""
    get{String <: AbstractString}(datasource::DatasourceService,
        key::Array{AbstractString, 1};

Returns multiple IO's reading the value in the datasource for the given keys.
Optionally allow skipping any cached values.
"""
# Using parametrics because as of 0.4.6 can not promote Array{ASCIIString, 1}
# to Array{AbstractString, 1}
function get{String <: AbstractString}(datasource::DatasourceService,
        keys::Array{String, 1}; override_cache::Bool=false)
    return pmap((key) -> Datasource.get(datasource, key;
        override_cache=override_cache), keys)
end

"""
    put!(datasource::DatasourceService, key::AbstractString,
        new_value::Union{IO, Void}=nothing; only_cache::Bool=false)

Put in a new value into the datasource for the given key. The new value can be
specified by the input IO or if no IO is specified, it will be pulled from the
cache. Optionally allow putting the new value into the cache only.

NOTE: The operation is undefined if only_cache = true and input new_value IO is
not specified.
"""
function put!(datasource::DatasourceService, key::AbstractString,
        new_value::Union{IO, Void}=nothing; only_cache::Bool=false)
    error("put! is not implemented for $datasource")
end

"""
    put!{String <: AbstractString, I <: IO}(
        datasource::DatasourceService, keys::Array{String, 1},
        new_values::Array{I, 1}; only_cache::Bool=false)

Put in new values into the datasource for the given keys. The new value can be
specified by the input IO or if no IO is specified, it will be pulled from the
cache. Optionally allow putting the new value into the cache only.

NOTE: The operation is undefined if only_cache = false and input new_value IO is
not specified.
"""
# Using parametrics because as of 0.4.6 can not promote Array{ASCIIString, 1}
# to Array{AbstractString, 1}
function put!{String <: AbstractString, I <: Union{IO, Void}}(
        datasource::DatasourceService, keys::Array{String, 1},
        new_values::Array{I, 1}; only_cache::Bool=false)
    return pmap((index) -> Datasource.put!(datasource, keys[index],
        new_values[index]; only_cache=only_cache), 1:length(keys))
end

function put!{String <: AbstractString}(
        datasource::DatasourceService, keys::Array{String, 1};
        only_cache::Bool=false)
    return pmap((index) -> Datasource.put!(datasource, keys[index],
        nothing; only_cache=only_cache), 1:length(keys))
end

"""
    clear!(datasource::DatasourceService, key::AbstractString};
        only_cache::Bool=false)

Remove the value from the datasource. Optionally only remove from cache.
"""
function remove!(datasource::DatasourceService, key::AbstractString;
        only_cache::Bool=false)
    error("remove! is not implemented for $datasource")
end

"""
    remove!{String <: AbstractString}(datasource::DatasourceService,
        keys::Array{String, 1}; only_cache::Bool=false)

Remove multiple keys from the datasource. Optionally only remove from cache
"""
function remove!{String <: AbstractString}(datasource::DatasourceService,
        keys::Array{String, 1}; only_cache::Bool=false)
    return pmap((key) -> Datasource.remove!(datasource, key;
        only_cache=only_cache), keys)
end

"""
    clear!()

Clear the datasource!
"""
function clear_cache(datasource::DatasourceService)
    error("clear_cache! is not implemented for $datasource")
end

end # module Datasource
