module CLIBucket

using ...SimpleTasks.Types

import SimpleTasks.Services.Bucket

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

const megabyte = 1024 * 1024
const write_bytes = 50 * megabyte
const read_bytes = 50 * megabyte


function check_reachable(provider::Provider, bucket_name::AbstractString)
    try
        # pipeline into DevNull to squelch stdout
        cmd = `$(provider.command) ls $(provider.prefix)/$bucket_name`
        run(pipeline(cmd, stdout=DevNull))
    catch
        throw(ArgumentError("Unable to access bucket \"$bucket_name\"")) 
    end
    return true
end

function Bucket.download(bucket::CLIBucketService,
    remote_file::AbstractString,
    local_file::Union{AbstractString, IO, Void}=nothing)

    download_cmd = `$(bucket.provider.command) cp
        $(bucket.provider.prefix)/$(bucket.name)/$remote_file -`

    s3_output = Pipe()
    # open the cmd in write mode. this automatically takes the 2nd arg
    # (stdio) and uses it as redirection of STDOUT.
    (s3_input, process) = open(download_cmd, "w", s3_output)
    close(s3_output.in)

    # Stop gap measure to check if we couldn't locate the file
    timedwait(() -> process_exited(process), 1.0)
    if !process_running(process) && !success(process)
        error("Error downloading $remote_file using command $download_cmd")
    end

    if local_file != nothing
        if isa(local_file, ASCIIString)
            local_file = open(local_file, "w")
        end
        while !eof(s3_output)
            write(local_file, readbytes(s3_output, write_bytes))
        end
        if !success(process)
            error("Download did not complete cleanly")
        end
    else
        local_file = s3_output
    end

    return local_file
end

function Bucket.upload(bucket::CLIBucketService,
        local_file::Union{AbstractString, IO}, remote_file::AbstractString)

    upload_cmd = `$(bucket.provider.command) cp -
        $(bucket.provider.prefix)/$(bucket.name)/$remote_file`

    s3_input = Pipe()
    # open the cmd in read mode. this automatically takes the 2nd arg
    # (stdio) and uses it as redirection of STDIN.
    (s3_output, process) = open(upload_cmd, "r", s3_input)

    # Stop gap measure to check if we couldn't upload the file
    timedwait(() -> process_exited(process), 1.0)
    if !process_running(process) && !success(process)
        error("Error uploading $remote_file using command $upload_cmd")
    end

    if isa(local_file, AbstractString)
        local_file = open(local_file, "r")
    end

    while !eof(local_file)
        write(s3_input, readbytes(local_file, read_bytes))
    end

    close(s3_input.in)

    if !success(process)
        error("Upload did not complete cleanly")
    end
end

end # module CLIBucket
