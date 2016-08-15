module TestCLIBucket

using Base.Test
using SimpleTasks.Services.CLIBucket

import AWS
import SimpleTasks.Services.Bucket
import SimpleTasks.Services.CLIBucket
import SimpleTasks.Services.AWSCLIProvider
import SimpleTasks.Services.GCSCLIProvider

const TEST_FILE_NAME = "testfile$(rand())"
const BUCKET_NAME = "seunglab-test"
const MAX_INDEX = 100000

macro silent(expr::Expr)
    return :(try run(pipeline($expr, stdout=DevNull, stderr=DevNull)) catch end)
end

function upload_remote_test_file(provider::CLIBucket.Provider)
    create_local_test_file(TEST_FILE_NAME)
    try
        run(`$(provider.command) cp $TEST_FILE_NAME
            $(provider.prefix)/$BUCKET_NAME/$TEST_FILE_NAME`)
    finally
        delete_local_test_file()
    end
end

function delete_remote_test_file(provider::CLIBucket.Provider)
    run(`$(provider.command) rm $(provider.prefix)/$BUCKET_NAME/$TEST_FILE_NAME`)
end

function write_numbers(io::IO)
    for i in 1:MAX_INDEX
        write(io, "$i\n")
    end
end

function create_local_test_file(filename::AbstractString)
    file = open(filename, "w")
    write_numbers(file)
    close(file)
end

function delete_local_test_file()
    rm(TEST_FILE_NAME)
end

function test_creatable(provider::CLIBucket.Provider)
    bucket = CLIBucketService(provider, BUCKET_NAME)
    @test bucket != nothing
end

function test_bad_bucket(provider::CLIBucket.Provider)
    @test_throws ArgumentError CLIBucketService(provider,
        "$BUCKET_NAME-bad")
end

function test_download_IO(provider::CLIBucket.Provider)
    upload_remote_test_file(provider)

    bucket = CLIBucketService(provider, BUCKET_NAME)

    buffer = IOBuffer()
    Bucket.download(bucket, TEST_FILE_NAME, buffer)

    file_indices = split(takebuf_string(buffer), "\n")
    for index in 1:length(file_indices) - 1
        @test parse(Int, file_indices[index]) == index
    end
    # last split from \n is generates an empty string
    @test length(file_indices) - 1 == MAX_INDEX

    delete_remote_test_file(provider)
end

function test_download_file(provider::CLIBucket.Provider)
    upload_remote_test_file(provider)

    bucket = CLIBucketService(provider, BUCKET_NAME)

    download_filename = "new$TEST_FILE_NAME"
    Bucket.download(bucket, TEST_FILE_NAME, download_filename)

    file = open(download_filename, "r")
    index = 0
    try
        while !eof(file)
            index = index + 1
            @test parse(Int, readline(file)) == index
        end
    finally
        close(file)
        rm(download_filename)
    end
    @test index == MAX_INDEX

    delete_remote_test_file(provider)
end

function test_download_stream(provider::CLIBucket.Provider)
    upload_remote_test_file(provider)

    bucket = CLIBucketService(provider, BUCKET_NAME)

    stream = Bucket.download(bucket, TEST_FILE_NAME)

    index = 0
    try
        while !eof(stream)
            index = index + 1
            @test parse(Int, readline(stream)) == index
        end
    finally
        close(stream)
    end
    @test index == MAX_INDEX

    delete_remote_test_file(provider)
end

function test_upload_io(provider::CLIBucket.Provider)
    bucket = CLIBucketService(provider, BUCKET_NAME)

    io = IOBuffer()
    write_numbers(io)
    seekstart(io)
    # also tests parentheses commas and underscores
    upload_filename = "$(TEST_FILE_NAME)UpIO(,_)"

    # try to remove the file we are tring to upload from bucket
    @silent `$(provider.command) rm $(provider.prefix)/$BUCKET_NAME/$upload_filename`

    Bucket.upload(bucket, io, upload_filename)

    # Verify the uploaded file by manually download the uploaded file
    try
        run(`$(provider.command) cp $(provider.prefix)/$BUCKET_NAME/$upload_filename $upload_filename`)
    catch
        error("Unable to find downloaded file $upload_filename")
    end

    downloaded_file = open(upload_filename, "r")
    index = 0
    try
        while !eof(downloaded_file)
            index = index + 1
            @test parse(Int, readline(downloaded_file)) == index
        end
    finally
        close(downloaded_file)
        rm(upload_filename)
    end
    @test index == MAX_INDEX
    @silent `$(provider.command) rm $(provider.prefix)/$BUCKET_NAME/$upload_filename`
end

function test_upload_file(provider::CLIBucket.Provider)
    bucket = CLIBucketService(provider, BUCKET_NAME)

    upload_filename = "$(TEST_FILE_NAME)UpFile"
    # try to remove the file we are tring to upload from bucket
    @silent `$(provider.command) rm $(provider.prefix)/$BUCKET_NAME/$upload_filename`

    create_local_test_file(upload_filename)

    Bucket.upload(bucket, upload_filename, upload_filename)

    # Verify the uploaded file by manually download the uploaded file
    try
        run(`$(provider.command) cp
            $(provider.prefix)/$BUCKET_NAME/$upload_filename $upload_filename`)
    catch
        error("Unable to find downloaded file $upload_filename")
    end

    downloaded_file = open(upload_filename, "r")
    index = 0
    try
        while !eof(downloaded_file)
            index = index + 1
            @test parse(Int, readline(downloaded_file)) == index
        end
    finally
        close(downloaded_file)
        rm(upload_filename)
    end
    @test index == MAX_INDEX
    @silent `$(provider.command) rm $(provider.prefix)/$BUCKET_NAME/$upload_filename`
end

function test_delete_file_exists(provider::CLIBucket.Provider)
    upload_remote_test_file(provider)

    bucket = CLIBucketService(provider, BUCKET_NAME)
    Bucket.delete(bucket, TEST_FILE_NAME)

    # Verify that the remote file was deleted
    try
        @test_throws ErrorException run(`$(provider.command) ls
                $(provider.prefix)/$BUCKET_NAME/$TEST_FILE_NAME`)
    finally
        # Remove the test file if we had been unable to remove the file
        @silent `$(provider.command) rm $(provider.prefix)/$BUCKET_NAME/$TEST_FILE_NAME`
    end
end

function test_delete_file_not_exists(provider::CLIBucket.Provider)
    bucket = CLIBucketService(provider, BUCKET_NAME)
    # Verify that we throw an exception if the file doesn't exist
    @test_throws ArgumentError Bucket.delete(bucket, TEST_FILE_NAME)
end

function test_bucket(provider::CLIBucket.Provider)
    test_creatable(provider)
    test_bad_bucket(provider)

    test_download_IO(provider)
    test_download_file(provider)
    test_download_stream(provider)

    test_upload_io(provider)
    test_upload_file(provider)

    test_delete_file_exists(provider)
    test_delete_file_not_exists(provider)
end

function __init__()
    env = AWS.AWSEnv()
    aws_provider = AWSCLIProvider.Details(env)
    test_bucket(aws_provider)

    #=gcs_provider = GCSCLIProvider.Details()=#
    #=test_bucket(gcs_provider)=#
end

end # module TestCLIBucket
