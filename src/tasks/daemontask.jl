module DaemonTask

using ...SimpleTasks.Types

export Info, run, make_key

"""
    DaemonTask.Result

This object contains the outcome of performing the task.
"""
type Result
    success::Bool
    outputs::Array{AbstractString, 1}
end

# Test to see if the execute function exists for this type
function can_execute(task_type::Type)
    if !(task_type <: DaemonTaskDetails)
        return false
    end

    prepare_methods = methods(prepare, Type[task_type, DatasourceService])
    if length(prepare_methods) == 0
        return false
    end
    execute_methods = methods(execute, Type[task_type, DatasourceService])
    if length(execute_methods) == 0
        return false
    end
    finalize_methods = methods(finalize, Type[task_type, DatasourceService])
    if length(finalize_methods) == 0
        return false
    end
    for execute_method in execute_methods
        sig_types = execute_method.sig.types
        if  length(sig_types) > 0 && sig_types[1] == task_type
            return true
        end
    end
    return false
end

"""
    make_key(task::DaemonTaskDetails, input::AbstractString)

Get the fully qualified input key which is the input appended to the
base_directory of the task
"""
function make_key(task::DaemonTaskDetails, input::AbstractString)
    return "$(task.basic_info.base_directory)/$input"
end

"""
    run(task::DaemonTaskDetails, datasource::DatasourceService)

Run the current task. 1. Prepare, 2. Execute 3. Finalize
"""
function run(task::DaemonTaskDetails, datasource::DatasourceService)
    prepare(task, datasource)
    result = execute(task, datasource)
    finalize(task, datasource, result)
    return result;
end

"""
    prepare(task::DaemonTaskDetails, datasource::DatasourceService)

prepare what is needed for the task
"""
function prepare(task::DaemonTaskDetails, datasource::DatasourceService)
    error("Prepare is unimplemented for this task $task")
end

"""
    execute(task::DaemonTaskDetails, datasource::DatasourceService)

Executes the given task. Must be overriden for new tasks
"""
function execute(task::DaemonTaskDetails, datasource::DatasourceService)
    error("Execute is unimplemented for this task $task")
end

"""
    finalize(daemon::DaemonService, task::DaemonTaskDetails,

After task has completed, perform this action
"""
function finalize(task::DaemonTaskDetails, datasource::DatasourceService)
    error("finalize is unimplemented for this task $task")
end

end # module DaemonTask
