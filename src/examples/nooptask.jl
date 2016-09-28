"""
    NoOpTask

This module includes the composite type NoOpDetails which includes both the
        generic DaemonTask.Info and an AbstractString as a payload
"""
module NoOpTask

using ...SimpleTasks.Types

import SimpleTasks.Tasks.DaemonTask
import SimpleTasks.Tasks.BasicTask
import SimpleTasks.Services.Datasource

export NoOpTaskDetails, NAME, full_output_path

type NoOpTaskDetails <: DaemonTaskDetails
    basic_info::BasicTask.Info
    payload_info::AbstractString
end

const NAME = "NO_OP"
const OUTPUT_FOLDER = "0_output"

function full_output_path(task::NoOpTaskDetails,
        input::AbstractString)
    path_end = rsearch(input, "/").start + 1

    return "$(task.basic_info.base_directory)/$OUTPUT_FOLDER/" *
        "$(input[path_end:end])"
end

function DaemonTask.prepare(task::NoOpTaskDetails,
        datasource::DatasourceService)
    # Prime the cache
    Datasource.get(datasource,
        map((input) -> DaemonTask.make_key(task, input), task.basic_info.inputs))
end

function DaemonTask.execute(task::NoOpTaskDetails,
        datasource::DatasourceService)
    inputs = task.basic_info.inputs

    if length(inputs) == 0
        return DaemonTask.Result(true, [])
    end

    # Arbitrarily print out some of the first and last characters of the input
    for input in inputs
        data_stream = Datasource.get(datasource,
            DaemonTask.make_key(task, input))
        if data_stream != nothing
            data = readall(data_stream)
            println("Input: $input contains $(data[1:min(10, end)]) \nto\n" *
                "$(data[max(1, end-10):end])")
        end
    end

    # setting new values into the cache
    output_keys = map((input) -> full_output_path(task, input), inputs);
    output_streams = map((input) ->
        Datasource.get(datasource, DaemonTask.make_key(task, input)), inputs)
    Datasource.put!(datasource, output_keys, output_streams; only_cache = true)

    return DaemonTask.Result(true, output_keys)
end

function DaemonTask.finalize(task::NoOpTaskDetails,
        datasource::DatasourceService, result::DaemonTask.Result)
    if !result.success
        error("Task $(task.basic_info.id), $(task.basic_info.name) was " *
            "not successful")
    else
        println("Task $(task.basic_info.id), $(task.basic_info.name) was " *
            "completed successfully, syncing outputs to remote datasource")
        Datasource.put!(datasource,
            map((output) -> full_output_path(task, output), result.outputs))
    end

    # Arbitrarily delete the first input file from the cache
    if !isempty(task.basic_info.inputs)
        Datasource.delete!(datasource,
            DaemonTask.make_key(task, task.basic_info.inputs[1]);
                only_cache=true)
    end
end

end # module BlockMatchTask
