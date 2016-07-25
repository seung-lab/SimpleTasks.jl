module TestDaemonTask

using Base.Test
using Julitasks.Types
using JulitasksTests.Utils.MockServices

import Julitasks.Tasks.DaemonTask
import Julitasks.Tasks.DaemonTask

type NewTask <: DaemonTaskDetails end
function test_execute_undefined_task()
    task = NewTask()
    datasource = MockDatasourceService()
    @test_throws ErrorException DaemonTask.execute(task, datasource)
end

function __init__()
    test_execute_undefined_task()
end

end # module TestDaemonTask
