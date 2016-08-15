include("../SimpleTasks.jl")

module AWSScheduler

using SimpleTasks.Types
using SimpleTasks.Services.AWSQueue
using SimpleTasks.Services.CLIBucket
using SimpleTasks.Services.AWSCLIProvider
using SimpleTasks.Examples.NoOpTask

import AWS
import JSON
import SimpleTasks.Services.Bucket
import SimpleTasks.Services.Queue
import SimpleTasks.Tasks.BasicTask

const LOCAL_PREFIX = "/var/tmp/taskdaemon"
const BASE_DIRECTORY = "datasets/noop_dataset"

type ScheduleConfig
    task_queue_name::ASCIIString
    bucket_name::ASCIIString
end

const KEY_FOLDER = "0_input"
# datasets/noop_dataset/0_input
const FULL_PATH = "$BASE_DIRECTORY/$KEY_FOLDER"
# /var/tmp/datasets/noop_dataset/0_input
const FULL_LOCAL_PATH = "$LOCAL_PREFIX/$FULL_PATH"

function to_name(index::Int64)
    return "$index.dat"
end

function to_key(index::Int64)
    return "$KEY_FOLDER/$(to_name(index))"
end

function to_full_path(index::Int64)
    return "$FULL_PATH/$(to_name(index))"
end

function to_full_local_path(index::Int64)
    return "$FULL_LOCAL_PATH/$(to_name(index))"
end

function create_input_file(index::Int64)
    filename = to_full_local_path(index)
    file = open(filename, "w")
    for value in index*1000000:(index + 1)*1000000
        write(file, "$value\n")
    end
    close(file)
    return filename
end

function create_input_files(indices::UnitRange{Int64})
    mkpath("$FULL_LOCAL_PATH")
    input_filenames = map(create_input_file, indices)
    bucket_paths = map(to_full_path, indices)

    return zip(input_filenames, bucket_paths)
end

function create_task(index::Int64)
    task_indices = index:index+1
    basic_info = BasicTask.Info(index, NoOpTask.NAME, BASE_DIRECTORY,
        map(to_key, task_indices))
    task = NoOpTaskDetails(basic_info, "NoOp Task for $task_indices")
    return task
end

function schedule(queue_name, bucket_name)
    env = AWS.AWSEnv()
    queue = AWSQueueService(env, queue_name)
    bucket = CLIBucketService(AWSCLIProvider.Details(env), bucket_name)

    # create data and upload it to the bucket service
    indices = 0:9
    inouts = create_input_files(indices)
    map((inout) -> Bucket.upload(bucket, inout[1], inout[2]), inouts)

    # create tasks from the inputs and add them to the queue
    tasks = map(create_task, indices[1:end-1])
    map((task) -> Queue.push_message(queue; message_body = JSON.json(task)),
        tasks)
end

"""
    parse_args()
Parse ARGS into scheduler configuration.
Return ScheduleConfig
"""
function parse_args()
    if length(ARGS) < 2
        error("Not enough arguments given, (given $ARGS) sample usage:
            -- julia awsscheduler.jl task_queue_name bucket_name")
    end

    schedule_config = ScheduleConfig(
        ASCIIString(ARGS[1]),
        ASCIIString(ARGS[2])
    )
    return schedule_config
end

function __init__()
    schedule_config = parse_args()
    #=schedule_config = ScheduleConfig("task-queue-TEST", "seunglab-test")=#
    schedule(schedule_config.task_queue_name, schedule_config.bucket_name)
end

end # module AWSScheduler
