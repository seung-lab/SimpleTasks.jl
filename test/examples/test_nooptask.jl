module TestNoOpTask

using Base.Test
using JulitasksTests.Utils.TestTasks
using JulitasksTests.Utils.MockServices
using Julitasks.Examples.NoOpTask

import Julitasks.Tasks.DaemonTask
import Julitasks.Tasks.BasicTask
import Julitasks.Services.Datasource

function test_create()
    task = NoOpTaskDetails(make_valid_basic_info(), "TEST")
    task.basicInfo.name = NoOpTask.NAME
    @test task != nothing
end

function test_run()
    task = NoOpTaskDetails(make_valid_basic_info(), "TEST")
    task.basicInfo.name = NoOpTask.NAME
    datasource = MockDatasourceService()

    #prime the cache
    for test_input in TEST_INPUTS
        buffer = IOBuffer(test_input)
        seekstart(buffer)
        Datasource.put!(datasource, full_input_path(task, test_input), buffer)
        Datasource.put!(datasource, full_output_path(task, test_input), buffer)
    end

    DaemonTask.run(task, datasource)
end

function __init__()
    test_create()
    test_run()
end

end # module TestNoOpTask
