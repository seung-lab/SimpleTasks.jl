#SimpleTasks [![Build Status](https://travis-ci.org/seung-lab/SimpleTasks.jl.svg?branch=master)](https://travis-ci.org/seung-lab/SimpleTasks.jl)

##Why do you want this?
You need to parallelize simple processes in the cloud using Julia.

##How does it work?
You provide a ```QueueService``` (AWS SQS implementation provided) and a ```BucketService``` (AWS S3 and GCS implementation provided).  Tasks are scheduled into your ```QueueService``` and data is pulled from your ```BucketService``` for processing and results are pushed back to your ```BucketService``` 

See [Advanced](#advanced) for additional customization options.

##Sounds great! Set me up! (Installation)
See REQUIRE file for required packages. You may need to run ```sudo apt-get install build-essential cmake``` to build certain required projects.

Julia's package manager should handle the rest ```Pkg.add("SimpleTasks")```.

To use ```BucketService``` with AWS, you must have the latest AWS CLI version
```
# Check current version -- too old :(
$aws --version
aws-cli/1.2.9 Python/3.4.3 Linux/3.13.0-74-generic

# Update aws cli
$sudo pip install awscli 
...

# Check new version -- Great! :D
$aws --version
aws-cli/1.10.56 Python/2.7.6 Linux/3.13.0-74-generic botocore/1.4.46
```
##Let's do this!
###Tutorial
1. Create one or many ```DaemonTask```s
  See [nooptask.jl](src/examples/nooptask.jl) for inspiration.
  
  Relevant parts are:
  * Custom Task Type
    ``` julia
    type NoOpTaskDetails <: DaemonTaskDetails
      basic_info::BasicTask.Info
      payload_info::AbstractString
    end
    ```
    
    This type must be JSON serializable. 
    ```basic_info``` is described below
    ```payload_info``` does not need to be of AbstractString. See [Custom Payload](#custom-payload) for more details.
  * BasicTask.Info already implemented as:
    ``` julia
    type Info
      id::Int64                           # Numerical identifier for specific task
      name::AbstractString                # String identifer for the type of task
      base_directory::AbstractString       # Base directory for fetching input data
      inputs::Array{AbstractString, 1}    # Names of files we are fetching
    end
    ```
    
  * Const unique identifier saved in the task to let SimpleTasks to know how to run it.
    ``` julia
    const NAME = "NO_OP"
    ```
    
  * DaemonTask.prepare - function for data prep / download data
  * DaemonTask.execute - function for task execution
  * DaemonTask.finalize - function for cleanup / upload data

2. Create a Run File to register your tasks
  See [runawsdaemon.jl](src/examples/runawsdaemon.jl) for inspiration.
  
  Relevant parts are:
  ``` julia
  # Load AWS credentials via AWS library (either through environment
  # variables or ~/.awssecret or query permissions server)
  env = AWS.AWSEnv()
 
  # Create a queue to read tasks from
  task_queue = AWSQueueService(env, task_queue_name)

  # Create a queue to write errors to
  error_queue = AWSQueueService(env, error_queue_name)

  # Create a datasource to read and write data from
  bucket = CLIBucketService(AWSCLIProvider.Details(env), bucket_name)
  cache = FileSystemCacheService(cache_directory)
  datasource = BucketCacheDatasourceService(bucket, cache)

  # create a daemon to run tasks
  daemon = DaemonService(task_queue, error_queue, bucket, datasource,
      poll_frequency_seconds)

  # Register the NOOP task
  register!(daemon, NoOpTask.NAME, NoOpTaskDetails)

  # Start the daemon
  Daemon.run(daemon)
  ```
  
3. Schedule events
  See [awsscheduler.jl](src/examples/awsscheduler.jl) for inspiration.
  
  Relevant parts are:
  ``` julia
   task = NoOpTaskDetails(basic_info, "NoOp Task for $task_indices")
   ...
   map((task) -> Queue.push_message(queue; message_body = JSON.json(task)), tasks)
  ```
  
4. Run
  ```julia
  julia -e  julia /home/ubuntu/.julia/v0.4/SimpleTasks/src/examples/runhybriddaemon.jl TASK_QUEUE_NAME ERROR_QUEUE_NAME BUCKET_NAME CACHE_DIRECTORY POLL_FREQUENCY_SECONDS
  ```

###Generated Results
* Example of generated task
  ``` json
  {
    "basic_info": {
      "id": 4,
      "name": "NO_OP",
      "base_directory": "datasets\/noop_dataset",
      "inputs": [
        "0_input\/4.dat",
        "0_input\/5.dat"
      ]
    },
    "payload_info": "NoOp Task for 4:5"
  }
  ```
  
* Example of generated data:
  * Input
    * AWS S3
      ```
      s3://BUCKET_NAME/datasets/noop_dataset/0_input/4.dat
      s3://BUCKET_NAME/datasets/noop_dataset/0_input/5.dat
      ```
      
    * Local
      ```
      /var/tmp/taskdaemon/datasets/noop_dataset/0_input/4.dat
      /var/tmp/taskdaemon/datasets/nooop_dataset/0_input/5.dat
      ```
      
  * Output
    * AWS S3
      ```
      s3://BUCKET_NAME/datasets/noop_dataset/0_output/4.dat
      s3://BUCKET_NAME/datasets/noop_dataset/0_output/5.dat
      ```
      
    * Local
      ```
      /var/tmp/taskdaemon/datasets/noop_dataset/0_output/4.dat
      /var/tmp/taskdaemon/datasets/noop_dataset/0_output/5.dat
      ```
      
  

##Advanced
###Custom Payload
Use case: You have many inputs to your task that are not captured by a simple AbstractString

1. Create a new type for your task specific inputs
  ``` julia
  type ComplexPayload
    complexID::Int64
    thresholds::Array{Int64, 1}
  end
  ```
  
2. Create a custom constructor for your custom payload type that accepts a JSON parsed dictionary
  ``` julia
  function ComplexPayload.Info{String <: AbstractString}(dict::Dict{String, Any})
  # do your parsing from JSON parsed dictionary here
  ...
  return ComplexPayload.Info(...)
  end
  ```
  
3. Set your task's ```payload_info``` to use that type
  ``` julia
  type ComplexPayloadTask <: DaemonTaskDetails
      basic_info::BasicTask.Info
      payload_info::ComplexPayload.Info
  end
  ```
  
4. Create your task constructor to automatically call the payload dictionary constructor
  ``` julia
  ComplexPayloadTask{String <: AbstractString}(basic_info::BasicTask.Info,
    dict::Dict{String, Any}) = ComplexPayloadTask(basic_info, ComplexPayload.Info(dict))
  ```

###What if I don't use AWS or GCS?
Extend [queue.jl](src/services/queue.jl) and/or [bucket.jl](src/services/bucket.jl) and plug those into the daemon.

###Datasource
Note that the bucket layout that corresponds to the ```BasicTask.Info```

```
s3://BUCKET_NAME/datasets/dataset_name/task_folder/input.h5
```

```
# info is of type BasicTask.info
info.base_directory = "datasets/dataset_name"
info.inputs[1] = "task_folder/input.h5"
```

####Warning
The provided ```FileSystemCache``` uses the filesystem. No guarantees are made to make this safe (for now)

##Cloud
###Google Cloud startup script:
```
#! /bin/bash
export AWS_ACCESS_KEY_ID=$(curl http://metadata.google.internal/computeMetadata/v1/project/attributes/aws-sqs-access-id -H "Metadata-Flavor: Google")
export AWS_SECRET_ACCESS_KEY=$(curl http://metadata.google.internal/computeMetadata/v1/project/attributes/aws-sqs-secret-access-key -H "Metadata-Flavor: Google")
export TASK_QUEUE=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/task-queue -H "Metadata-Flavor: Google")
export ERROR_QUEUE=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/error-queue -H "Metadata-Flavor: Google")
export BUCKET_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/bucket-name -H "Metadata-Flavor: Google")
export CACHE_DIRECTORY=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/cache-directory -H "Metadata-Flavor: Google")
export POLL_FREQUENCY_SECONDS=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/poll-frequency-seconds -H "Metadata-Flavor: Google")
sudo -u ubuntu -H sh -c "stdbuf -oL -eL julia /home/ubuntu/.julia/v0.4/SimpleTasks/src/examples/runhybriddaemon.jl $TASK_QUEUE $ERROR_QUEUE $BUCKET_NAME $CACHE_DIRECTORY $POLL_FREQUENCY_SECONDS | tee -a /home/ubuntu/daemon.out &"
```

##Troubleshooting
### My downloaded files are showing up as ```download: s3://xxxx to ./-```
Your AWS CLI is TOO OLD! [Update it!](#sounds-great-set-me-up-installation)

##Feature Wishlist
* Dependency scheduling ? (retasking)

