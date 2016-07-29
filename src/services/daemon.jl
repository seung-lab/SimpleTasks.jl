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
    bucket::BucketService
    datasource::DatasourceService
    poll_frequency_seconds::Int64
    tasks::Dict{AbstractString, Type}
end

type TaskExceptionReport
    task_message::AbstractString
    exception_message::AbstractString
end

DaemonService(task_queue::QueueService, error_queue::QueueService,
    bucket::BucketService, datasource::DatasourceService,
    poll_frequency_seconds::Int64) = 
        DaemonService(task_queue, error_queue, bucket, datasource,
            poll_frequency_seconds, Dict{AbstractString, Module}())

function run(daemon::DaemonService)
    while true
        message = ""
        try
            message = Queue.pop_message(daemon.task_queue)

            if isempty(message)
                println("No messages found in", Queue.string(daemon.task_queue))
            else
                println("Message received is $(message)")

                try
                    task = parse(daemon, message)

                    println("Task is $(task.basicInfo.id), ",
                        task.basicInfo.name)

                    success = DaemonTask.run(task, daemon.datasource)
                catch task_exception
                    exception_buffer = IOBuffer()
                    showerror(exception_buffer, task_exception,
                        catch_backtrace(); backtrace = true)
                    seekstart(exception_buffer)
                    notify_task_error(daemon.error_queue,
                        TaskExceptionReport(message, readall(exception_buffer)))
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

"""
    notify_task_error(queue::QueueService, task_message::AbstractString,
        exception::Exception)
"""
function notify_task_error(queue::QueueService,
        error_report::TaskExceptionReport)
    try
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

    basic_info = BasicTask.Info(message["basicInfo"])

    if !haskey(daemon.tasks, basic_info.name)
        error("Task $(basic_info.name) is not registered with the daemon")
    end

    task_type = daemon.tasks[basic_info.name]
    return task_type(basic_info, message["payloadInfo"])
end

end # end module Daemon
