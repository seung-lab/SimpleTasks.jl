module FileSystemCache

using ...Julitasks.Types

import Julitasks.Services.Bucket
import Julitasks.Services.Cache

export FileSystemCacheService

const FOLDER_SEPARATOR = "/"

type FileSystemCacheService <: CacheService
    baseDirectory::AbstractString

    FileSystemCacheService(baseDirectory::AbstractString) =
        isempty(strip(baseDirectory)) ?  throw(ArgumentError("Base directory can
            not be empty")) : new(baseDirectory)
end

function sanitize(key::AbstractString)
    return replace(key, r"\.\.", "")
end

function to_filename(cache::FileSystemCacheService, key::AbstractString)
    return "$(cache.baseDirectory)$FOLDER_SEPARATOR$(sanitize(key))"
end

function create_path(full_path_file_name::AbstractString)
    path_end = rsearch(full_path_file_name, "/").start
    if path_end > 0
        mkpath(full_path_file_name[1:path_end])
    end
end

function Cache.exists(cache::FileSystemCacheService, key::AbstractString)
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
        write(filestream, readbytes(value_io))
        close(filestream)
    catch e
        close(filestream)
        # if there was an error in writing, we should delete the file so it
        # doens't count as being cached
        showerror(STDERR, e, catch_backtrace(); backtrace = true)
        rm(filename)
        error("Unable to put into cache $key")
    end
end

function Cache.get(cache::FileSystemCacheService, key::AbstractString)
    if Cache.exists(cache, key)
        return open(to_filename(cache, key), "r")
    else
        return nothing
    end
end

function Cache.delete!(cache::FileSystemCacheService, key::AbstractString)
    rm(to_filename(cache, key))
end

end # module FileSystemCache