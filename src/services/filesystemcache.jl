module FileSystemCache

using ...SimpleTasks.Types

import SimpleTasks.Services.Bucket
import SimpleTasks.Services.Cache

export FileSystemCacheService

const FOLDER_SEPARATOR = "/"

type FileSystemCacheService <: CacheService
    base_directory::AbstractString

    FileSystemCacheService(base_directory::AbstractString) =
        isempty(strip(base_directory)) ?  throw(ArgumentError("Base directory can
            not be empty")) : new(base_directory)
end

const MEGABYTE = 1024 * 1024
const WRITE_BYTES = 50 * MEGABYTE

function sanitize(key::AbstractString)
    return replace(key, r"\.\.", "")
end

function to_filename(cache::FileSystemCacheService, key::AbstractString)
    return "$(cache.base_directory)$FOLDER_SEPARATOR$(sanitize(key))"
end

function create_path(full_path_file_name::AbstractString)
    path_end = rsearch(full_path_file_name, "/").start
    if path_end > 0
        mkpath(full_path_file_name[1:path_end])
    end
end

function Cache.haskey(cache::FileSystemCacheService, key::AbstractString)
    filename = to_filename(cache, key)
    return isfile(filename) && isreadable(filename)
end

function Cache.put!(cache::FileSystemCacheService, key::AbstractString,
        value_io::IO)
    filename = to_filename(cache, key)
    create_path(filename)
    filestream = open(filename, "w")
    try
        if !iswritable(filestream)
            error("Unable to write to $filename")
        end

        if typeof(value_io) <: IOBuffer && position(value_io) == value_io.size
            println("wARNING: trying to read from an IOBuffer with current " *
                "position at the end of the buffer")
        end
        while !eof(value_io)
            write(filestream, readbytes(value_io, WRITE_BYTES))
        end
        close(filestream)
    catch e
        # if there was an error in reading/writing the stream, we should
        # clear the file in case of transmission error
        truncate(filestream, 0)
        println(STDERR, "Clearing FSCache for $key in $filename due to " *
            "stream error")
        showerror(STDERR, e, catch_backtrace(); backtrace = true)
        # error is thrown later on because the file is empty
    end

    # if the outcome of the put resulted in an empty file, then remove it
    # from the cache
    close(filestream)
    if Cache.haskey(cache, key) && stat(filename).size == 0
        rm(filename)
        error("Tried to cache an empty file $key into $filename")
    end
end

function Cache.get(cache::FileSystemCacheService, key::AbstractString)
    if Cache.haskey(cache, key)
        return open(to_filename(cache, key), "r")
    else
        throw(KeyError(key))
    end
end

function Cache.delete!(cache::FileSystemCacheService, key::AbstractString)
    if Cache.haskey(cache, key)
        rm(to_filename(cache, key))
    end
    return cache
end

function Cache.clear!(cache::FileSystemCacheService)
    contents = readdir(cache.base_directory)
    for content in contents
        rm(to_filename(cache, content); recursive=true)
    end
end

end # module FileSystemCache
