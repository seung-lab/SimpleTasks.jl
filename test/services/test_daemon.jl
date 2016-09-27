module TestDaemonService

using Base.Test
using SimpleTasksTests.Utils.TestTasks
using SimpleTasksTests.Utils.MockServices
using SimpleTasks.Services.Daemon

import SimpleTasks.Services.Queue
import SimpleTasks.Services.Bucket
import SimpleTasks.Services.Datasource
import SimpleTasks.Tasks.DaemonTask
import JSON

function make_mock_daemon_service()
    return DaemonService(MockQueueService(), MockQueueService(),
        MockQueueService(), MockBucketService(), MockDatasourceService(), 10)
end

function test_register_no_execute_method()
    daemon = make_mock_daemon_service()
    @test_throws Exception Daemon.register!(daemon,
        TEST_TASK_NAME, MockTaskNoExecute)
end

function test_register_with_execute_method()
    daemon = make_mock_daemon_service()
    exception = nothing
    try
         Daemon.register!(daemon, TEST_TASK_NAME, MockTaskExecute)
    catch e
        exception = e
    end
    @test exception == nothing
end

function test_parse_empty()
    daemon = make_mock_daemon_service()
    @test_throws ArgumentError Daemon.parse(daemon, " ")
end

function test_parse_no_basic_info()
    daemon = make_mock_daemon_service()
    task = make_valid_task_execute()
    dict = JSON.parse(JSON.json(task))
    delete!(dict, "basic_info")
    @test_throws KeyError Daemon.parse(daemon, JSON.json(dict))
end

function test_parse_no_payload_info()
    daemon = make_mock_daemon_service()
    task = make_valid_task_execute()
    Daemon.register!(daemon, TEST_TASK_NAME, typeof(task))
    dict = JSON.parse(JSON.json(task))
    delete!(dict, "payload_info")
    @test_throws KeyError Daemon.parse(daemon, JSON.json(dict))
end

function test_parse_task_not_registered()
    daemon = make_mock_daemon_service()
    task = make_valid_task_execute()
    dict = JSON.parse(JSON.json(task))

    @test_throws ErrorException Daemon.parse(daemon, JSON.json(dict))
end

function test_parse_good()
    daemon = make_mock_daemon_service()
    task = make_valid_task_execute()
    Daemon.register!(daemon, TEST_TASK_NAME, typeof(task))
    dict = JSON.parse(JSON.json(task))
    parsed_task = Daemon.parse(daemon, JSON.json(dict))
    @test parsed_task != nothing
    @test parsed_task.basic_info.name == task.basic_info.name
    @test parsed_task.basic_info.id == task.basic_info.id
    @test parsed_task.payload_info == task.payload_info

end

function __init__()
    test_register_no_execute_method()
    test_register_with_execute_method()

    test_parse_empty()
    test_parse_no_basic_info()
    test_parse_task_not_registered()
    test_parse_good()
end

end #module TestDaemon
