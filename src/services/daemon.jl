module Daemon

using ...SimpleTasks.Types

import SimpleTasks.Services.Queue
import SimpleTasks.Services.Bucket
import SimpleTasks.Services.Datasource
import SimpleTasks.Tasks.DaemonTask
import SimpleTasks.Tasks.BasicTask
import JSON

export DaemonService, register!, run

type DaemonService
    task_queue::QueueService
    error_queue::QueueService
    done_queue::QueueService
    bucket::BucketService
    datasource::DatasourceService
    poll_frequency_seconds::Int64
    tasks::Dict{AbstractString, Type}
end

DaemonService(task_queue::QueueService, error_queue::QueueService,
    done_queue::QueueService, bucket::BucketService,
    datasource::DatasourceService, poll_frequency_seconds::Int64) =
        DaemonService(task_queue, error_queue, done_queue, bucket,
            datasource, poll_frequency_seconds,
            Dict{AbstractString, Module}())

########### Helper types for queue notification ###########

type DaemonHostInfo
    hostname::AbstractString
    user::AbstractString
end
DAEMON_HOST_INFO = DaemonHostInfo(gethostname(), ENV["USER"])

type ErrorReport
    host_info::DaemonHostInfo
    task::Union{AbstractString, DaemonTaskDetails}
    exception::AbstractString
end

type DoneReport
    host_info::DaemonHostInfo
    task::DaemonTaskDetails
    result::DaemonTask.Result
end

function run(daemon::DaemonService)
    while true
        message = ""
        try
            message = Queue.pop_message(daemon.task_queue)

            if isempty(message)
                println("No messages found in ", Queue.string(daemon.task_queue))
            else
                println("Message received is $(message)")

                task = nothing
                try
                    task = parse(daemon, message)

                    println("Task is $(task.basic_info.id), ",
                        task.basic_info.name)

                    result = DaemonTask.run(task, daemon.datasource)

                    notify_task_done(daemon.done_queue, task, result)
                catch task_exception
                    exception_buffer = IOBuffer()
                    showerror(exception_buffer, task_exception,
                        catch_backtrace(); backtrace = true)
                    seekstart(exception_buffer)
                    notify_task_error(daemon.error_queue,
                        task == nothing ? message : task,
                        readall(exception_buffer))
                    rethrow(task_exception)
                end
            end
        catch exception
            print(STDERR, "Daemon Exception: ")
            showerror(STDERR, exception, catch_backtrace(); backtrace = true)
            println(STDERR)
        end

        sleep(daemon.poll_frequency_seconds)
    end
end

function notify_task_done(queue::QueueService, task::DaemonTaskDetails,
        result::DaemonTask.Result)
    done_report = DoneReport(DAEMON_HOST_INFO, task, result)
    Queue.push_message(queue; message_body = JSON.json(done_report))
end

"""
    notify_task_error(queue::QueueService,
        task::Union{DaemonTaskDetails, AbstractString},
        exception_message::AbstractString)
"""
function notify_task_error(queue::QueueService,
        task::Union{DaemonTaskDetails, AbstractString},
        exception_message::AbstractString)
    try
        error_report = ErrorReport(DAEMON_HOST_INFO, task,
            exception_message)
        Queue.push_message(queue; message_body = JSON.json(error_report))
    catch notify_exception
        print(STDERR, "ERROR in notifying  error-queue ", Queue.string(queue),
            " (Keep looking below for the real Daemon exception):")
        showerror(STDERR, notify_exception, catch_backtrace(); backtrace = true)
        println(STDERR)
    end
end

"""
    register!(daemon::DaemonService, task_module::Module)

Register the task type generation for the given task_name

"""
function register!(daemon::DaemonService, task_name::AbstractString,
        task_type::Type)
    if !DaemonTask.can_execute(task_type)
        error("Can not register $task_type with name $task_name " *
            " in Daemon. Could not find a registered method to execute")
    end

    if haskey(daemon.tasks, task_name)
        warn("Daemon has already registered $task_name with " *
            "$(daemon.tasks[task_name])")
    end

    daemon.tasks[task_name] = task_type
end

"""
    parse(daemon::DaemonService, text::ASCIIString)

Parse input JSON message into a task object
"""
function parse(daemon::DaemonService, text::ASCIIString)
    text = strip(text)

    if isempty(text)
        throw(ArgumentError("Trying to parse empty string for task"))
    end

    message = JSON.parse(text)

    basic_info = BasicTask.Info(message["basic_info"])

    if !haskey(daemon.tasks, basic_info.name)
        error("Task $(basic_info.name) is not registered with the daemon")
    end

    task_type = daemon.tasks[basic_info.name]
    return task_type(basic_info, message["payload_info"])
end

end # end module Daemon
