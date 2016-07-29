module Queue

using ...SimpleTasks.Types

export pop_message

"""
    pop_message(queue::QueueService)

Pop a message of the queue.
"""
function pop_message(queue::QueueService)
    error("pop_message for $queue is not implemented")
end

"""
    push_message(queue::QueueService)

Push a message onto the queue
"""
function push_message(queue::QueueService; attributes::Dict{AbstractString,
        Union{AbstractString, Number, Array{UInt8, 1}}} = MessageAtributeType[],
        messsage_body::AbstractString = "")
    error("push_message for $queue is not implemented")
end

end # module Queue
