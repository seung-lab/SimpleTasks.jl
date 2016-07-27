module CLIBucket

using ...Julitasks.Types

import Julitasks.Services.Bucket

export CLIBucketService

type Provider
    prefix::Cmd
    command::Cmd
end

type CLIBucketService <: BucketService
    provider::Provider
    name::AbstractString

    CLIBucketService(provider::Provider, name::AbstractString) =
        check_reachable(provider, name) && new(provider, name)
end


function check_reachable(provider::Provider, bucket_name::AbstractString)
    try
        # pipeline into DevNull to squelch stdout
        cmd = `$(provider.command) ls $(provider.prefix)/$bucket_name`
        run(pipeline(cmd, stdout=DevNull, stderr=DevNull))
    catch
        throw(ArgumentError("Unable to access bucket \"$bucket_name\"")) 
    end
    return true
end

function Bucket.download(bucket::CLIBucketService,
    remote_file::AbstractString,
    local_file::Union{AbstractString, IO, Void}=nothing)

    if isa(local_file, ASCIIString)
        local_file = open(local_file, "w")
    end

    download_cmd = `$(bucket.provider.command) cp
        $(bucket.provider.prefix)/$(bucket.name)/$remote_file -`

    if typeof(local_file) <: IOBuffer || local_file == nothing
        (s3_output, process) = open(download_cmd, "r")

        if typeof(local_file) <: IOBuffer
            # ugh julia doesn't support piping directly to IOBuffers yet so we need
            # manually read/write into the buffer, otherwise we can just use
            # open(..,"w", local_file)
            #=https://github.com/JuliaLang/julia/issues/14437=#
            write(local_file, readbytes(s3_output))
        else # local_file == nothing
            local_file = s3_output
        end
    else
        (s3_input, process) = open(download_cmd, "w", local_file)
        # for now just make it block until command has completed
        wait(process)
    end


    # Stop gap measure to check if we couldn't locate the file
    timedwait(() -> process_exited(process), 1.0)
    if !process_running(process) && !success(process)
        error("Error downloading $remote_file using command $download_cmd")
    end

    return local_file
end

function Bucket.upload(bucket::CLIBucketService,
        local_file::Union{AbstractString, IO}, remote_file::AbstractString)

    if isa(local_file, AbstractString)
        local_file = open(local_file, "r")
    end

    upload_cmd = `$(bucket.provider.command) cp -
        $(bucket.provider.prefix)/$(bucket.name)/$remote_file`

    # ugh julia doesn't support piping directly to IOBuffers yet
    #=https://github.com/JuliaLang/julia/issues/14437=#
    if typeof(local_file) <: IOBuffer

        if position(local_file) == local_file.size
            println("wARNING: trying to read from an IOBuffer with current " *
                "position at the end of the buffer")
        end

        (s3_input, process) = open(upload_cmd, "w")
        # manually read from buffer and write to stream
        write(s3_input, readbytes(local_file))
        close(s3_input)
    else
        # open the cmd in write mode. this automatically takes the 2nd arg
        # (stdio) and uses it as redirection of STDOUT.
        (s3_output, process) = open(upload_cmd, "r", local_file)
        # for now just make it block until command has completed until i know
        # how to make IOBuffer async/return a process
        wait(process)
    end

end

end # module CLIBucket
