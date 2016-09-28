module MockServices

using SimpleTasks.Types
using SimpleTasksTests.Utils.TestTasks

import SimpleTasks.Services.Queue
import SimpleTasks.Services.Bucket
import SimpleTasks.Services.Cache
import SimpleTasks.Services.Datasource

export MockBucketService
type MockBucketService <: BucketService
    mockFiles::Dict{AbstractString, Any}
end
MockBucketService() = MockBucketService(Dict())

# local_file can also be a file location but we're not testing that for now
function Bucket.download(bucket::MockBucketService, key::ASCIIString,
        local_file::Union{ASCIIString, IO, Void})
    data = bucket.mockFiles[key]
    if local_file != nothing
        write(local_file, readbytes(data))
        return local_file
    end
    seekstart(data)

    return IOBuffer(data)
end
# local_file can also be a file location but we're not testing that for now
function Bucket.upload(bucket::MockBucketService,
    local_file::Union{ASCIIString, IO}, key::ASCIIString)
    seekstart(local_file)
    data = IOBuffer()
    write(data, readbytes(local_file))
    seekstart(data)
    bucket.mockFiles[key] = data
end

function Bucket.delete(bucket::MockBucketService, key::AbstractString)
    delete!(bucket.mockFiles, key)
end


export MockQueueService
type MockQueueService <: QueueService
end
function Queue.pop_message(mock_queue::MockQueueService)
end

export MockCacheService
type MockCacheService <: CacheService
    mockValues::Dict{AbstractString, IO}
end
MockCacheService() = MockCacheService(Dict())
function Cache.haskey(cache::MockCacheService, key::AbstractString)
    return haskey(cache.mockValues, key)
end
function Cache.put!(cache::MockCacheService, key::AbstractString,
        value_buffer::IO)
    data = IOBuffer()
    write(data, readbytes(value_buffer))
    seekstart(data)
    cache.mockValues[key] = data
end
function Cache.get(cache::MockCacheService, key::AbstractString)
    if haskey(cache.mockValues, key)
        data = cache.mockValues[key]
        seekstart(data)
        return data
    else
        return nothing
    end
end
function Cache.delete!(cache::MockCacheService, key::AbstractString)
    delete!(cache.mockValues, key)
end
function Cache.clear!(cache::MockCacheService)
    empty!(cache.mockValues)
end

#This mock datasource has no cache!
export MockDatasourceService
type MockDatasourceService <: DatasourceService
    mockSource::Dict{AbstractString, IO}
end
MockDatasourceService() = MockDatasourceService(Dict())
function Datasource.get(datasource::MockDatasourceService,
        key::AbstractString; override_cache::Bool=false)
    if haskey(datasource.mockSource, key)
        data = datasource.mockSource[key]
        seekstart(data)
        return data
    else
        return nothing
    end
end
function Datasource.put!(datasource::MockDatasourceService, key::AbstractString,
        new_value::Union{IO, Void}=nothing; only_cache::Bool=false)
    if new_value != nothing
        data = IOBuffer()
        write(data, readbytes(new_value))
        seekstart(data)
        datasource.mockSource[key] = data
    end
end
function Datasource.delete!(datasource::MockDatasourceService,
    key::AbstractString; only_cache::Bool=false)
    delete!(datasource.mockSource, key)
end

function Datasource.clear_cache(datasource::MockDatasourceService)
end

end # module MockServices
