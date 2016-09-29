module Cache

using ...SimpleTasks.Types

import Base

export Service, exists, put!, get, delete!

"""
    haskey(cache::CacheService, key::AbstractString)

Returns true if the key is found in the cache.
"""
function Base.haskey(cache::CacheService, key::AbstractString)
    error("exists is unimplemented for $cache")
end

"""
    put!(cache::CacheService, key::AbstractString)

Reads the value from IO to store into the cache under the key.
"""
function put!(cache::CacheService, key::AbstractString, value_io::IO)
    error("put is unimplemented for $cache")
end
function Base.setindex!(cache::CacheService, value_io::IO, key::AbstractString)
    put!(cache, key, value_io)
end

"""
    get(cache::CacheService, key::AbstractString)

Get an IO stream to the object that is cached with this key.
Throws KeyError if key doesn't exist.
"""
function get(cache::CacheService, key::AbstractString)
    error("get is unimplemented for $cache")
end
function Base.getindex(cache::CacheService, key::AbstractString)
    get(cache, key)
end

"""
    delete!(cache::CacheService, key::AbstractString)

Delete the cached value for the given key.
Returns cache and does nothing if key is not found (this is what Julia
`Dict` does)
"""
function Base.delete!(cache::CacheService, key::AbstractString)
    error("delete! is unimplemented for $cache")
end

"""
    clear!(cache::CacheService)

Delete all cached items.
"""
function clear!(cache::CacheService)
    error("clear! is unimplemented for $cache")
end

end #module Cache
