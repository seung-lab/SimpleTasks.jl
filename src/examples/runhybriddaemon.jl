include("../Julitasks.jl")

module RunHybridDaemon

using Julitasks.Types
using Julitasks.Services.AWSQueue
using Julitasks.Services.CLIBucket
using Julitasks.Services.GCSCLIProvider
using Julitasks.Services.FileSystemCache
using Julitasks.Services.BucketCacheDatasource
using Julitasks.Services.Daemon
using Julitasks.Examples.NoOpTask

import AWS

type RunConfig
    task_queue_name::ASCIIString
    error_queue_name::ASCIIString
    bucket_name::ASCIIString
    cache_directory::ASCIIString
    poll_frequency_seconds::Int64
end

#=
 = Create the queue and bucket service and start the daemon
 =#
function run(task_queue_name, error_queue_name, bucket_name,
        cache_directory, poll_frequency_seconds)
    # Load AWS credentials via AWS library (either through environment
    # variables or ~/.awssecret or query permissions server)
    env = AWS.AWSEnv()

    task_queue = AWSQueueService(env, task_queue_name)

    error_queue = AWSQueueService(env, error_queue_name)

    bucket = CLIBucketService(GCSCLIProvider.Details(), bucket_name)

    cache = FileSystemCacheService(cache_directory)

    datasource = BucketCacheDatasourceService(bucket, cache)

    daemon = DaemonService(task_queue, error_queue, bucket, datasource,
        poll_frequency_seconds)

    register!(daemon, NoOpTask.NAME, NoOpTaskDetails)

    Daemon.run(daemon)
end

#=
 =Parse ARG into run daemon configuration.
 =Return RunConfig
 =#
function parse_args()
    if length(ARGS) < 3
        error("Not enough arguments given, (given $ARGS) sample usage:
            -- julia daemon.jl task_queue_name error_queue_name bucket_name " *
            " cache_directory poll_frequency_seconds")
    end

    run_config = RunConfig(
        ASCIIString(ARGS[1]),
        ASCIIString(ARGS[2]),
        ASCIIString(ARGS[3]),
        ASCIIString(ARGS[4]),
        parse(Int64, ARGS[5])
    )
    return run_config
end

#Run main!
function __init__()
    #=run_config = parse_args()=#
    run_config = RunConfig("task-queue-TEST", "error-queue-TEST", "seunglab-test",
        "/var/tmp/", 5)
    run(run_config.task_queue_name, run_config.error_queue_name,
        run_config.bucket_name, run_config.cache_directory,
        run_config.poll_frequency_seconds)
end

end # end module RunDaemon
