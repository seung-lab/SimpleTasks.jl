module BucketCacheDatasource

using ...SimpleTasks.Types

import SimpleTasks.Services.Bucket
import SimpleTasks.Services.Cache
import SimpleTasks.Services.Datasource

export BucketCacheDatasourceService

type BucketCacheDatasourceService <: DatasourceService
    remote::BucketService
    cache::CacheService
end

function Datasource.get(datasource::BucketCacheDatasourceService,
        key::AbstractString; override_cache::Bool=false)
    if override_cache || !haskey(datasource.cache, key)
        stream = Bucket.download(datasource.remote, key)
        datasource.cache[key] = stream
        close(stream)
    end
    return datasource.cache[key]
end

function Datasource.put!(datasource::BucketCacheDatasourceService,
        key::AbstractString, new_value::Union{IO, Void}=nothing;
        only_cache::Bool=false)
    if new_value != nothing
        seekstart(new_value)
        datasource.cache[key] = new_value
    end

    if !haskey(datasource.cache, key)
        return false
    end

    if !only_cache
        Bucket.upload(datasource.remote,
            datasource.cache[key], key)
    end
    return true
end

function Datasource.delete!(datasource::BucketCacheDatasourceService,
        key::AbstractString; only_cache::Bool=false)
    if !only_cache
        Bucket.delete(datasource.remote, key)
    end

    delete!(datasource.cache, key)
    return datasource
end

function Datasource.clear_cache(datasource::BucketCacheDatasourceService)
    Cache.clear!(datasource.cache)
end

end # module BucketCacheDatasource
