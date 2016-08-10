module Cache

using ...SimpleTasks.Types

export Service, exists, put!, get, delete!

"""
    exists(cache::CacheService, key::AbstractString)

Returns true if the key is found in the cache.
"""
function exists(cache::CacheService, key::AbstractString)
    error("exists is unimplemented for $cache")
end

"""
    put!(cache::CacheService, key::AbstractString)

Reads the value from IO to store into the cache under the key.
"""
function put!(cache::CacheService, key::AbstractString, value_io::IO)
    error("put is unimplemented for $cache")
end

"""
    get(cache::CacheService, key::AbstractString)

Get an IO stream to the object that is cached with this key.
Returns ```nothing``` if key is not found.
"""
function get(cache::CacheService, key::AbstractString)
    error("get is unimplemented for $cache")
end

"""
    remove!(cache::CacheService, key::AbstractString)

Remove the cached value for the given key.
"""
function remove!(cache::CacheService, key::AbstractString)
    error("remove! is unimplemented for $cache")
end

"""
    clear!(cache::CacheService)

Remove all cached items.
"""
function clear!(cache::CacheService)
    error("clear! is unimplemented for $cache")
end

end #module Cache
