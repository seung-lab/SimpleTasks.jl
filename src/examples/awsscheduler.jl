include("../Julitasks.jl")

module AWSScheduler

using Julitasks.Types
using Julitasks.Services.AWSQueue
using Julitasks.Services.CLIBucket
using Julitasks.Services.AWSCLIProvider
using Julitasks.Examples.NoOpTask

import AWS
import JSON
import Julitasks.Services.Bucket
import Julitasks.Services.Queue
import Julitasks.Tasks.BasicTask

const LOCAL_PREFIX = "/var/tmp"
const BASE_DIRECTORY = "datasets/noop_dataset"

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
    basicInfo = BasicTask.Info(index, NoOpTask.NAME, BASE_DIRECTORY,
        map(to_key, task_indices))
    task = NoOpTaskDetails(basicInfo, "NoOp Task for $task_indices")
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

function __init__()
    schedule("task-queue-TEST", "seunglab-test")
end

end # module AWSScheduler
