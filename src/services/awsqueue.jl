module AWSQueue

using ...SimpleTasks.Types

import AWS, AWS.SQS
import SimpleTasks.Services.Queue

export AWSQueueService

type AWSQueueService <: QueueService
    env::AWS.AWSEnv
    name::ASCIIString
    url::ASCIIString
end

AWSQueueService(env::AWS.AWSEnv, name::ASCIIString) =
        AWSQueueService(env, name, get_queue_url(env, name))

function Base.string(queue::AWSQueueService)
    return "$(queue.name) from $(queue.url)"
end

"""
    get_queue_url(env::AWS.AWSEnv, queue_name::AbstractString)

Find the correct url with our aws environment and bucket name
"""
function get_queue_url(env::AWS.AWSEnv, queue_name::AbstractString)
    response = SQS.CreateQueue(env, queueName = queue_name)

    # try creating a queue, does not overwrite existing queue so it's safe
    if response.http_code != 200
        error("Unable to create/get queue: $queue_name, response:
            ($(response.http_code))")
    end

    return response.obj.queueUrl
end

"""
    Queue.pop_message(queue::AWSQueueService)

Pop a message of the aws queue.
"""
function Queue.pop_message(queue::AWSQueueService)
    receive_response = SQS.ReceiveMessage(queue.env; queueUrl = queue.url)

    if receive_response.http_code != 200
        error("Unable to retrieve message from $queue")
    end

    if length(receive_response.obj.messageSet) < 1
        return ""
    end

    receiptHandle=receive_response.obj.messageSet[1].receiptHandle

    delete_response = SQS.DeleteMessage(queue.env; queueUrl = queue.url,
        receiptHandle = receiptHandle)

    return strip(receive_response.obj.messageSet[1].body)
end

"""
    to_SQS_attribute(attribute::Array{Tuple{AbstractString,
        Union{AbstractString, Number, Array{Uint8, 1}}}, 1})

Convert the attribute pair into AWS.SQSMessageAttributeType
"""
function to_SQS_attribute(attribute::Pair{AbstractString,
        Union{AbstractString, Number}})
    return AWS.SQS.MessageAttributeType(name = attribute[1],
        value = AWS.SQS.MessageAttributeValueType(
            dataType = typeof(attribute[2]), stringValue = attribute[2]))
end
function to_SQS_attribute(attribute::Pair{AbstractString, Array{UInt8, 1}})
    return AWS.SQS.MessageAttributeType(name = attribute[1],
        value = AWS.SQS.MessageAttributeValueType(
            dataType = "Binary", stringValue = attribute[2]))
end

"""
Push a message onto the aws queue.
Inputs:
    attributes - should be a Dict of attributes that can either bet a String,
        a Number, or a Byte array for Binary data
"""
function Queue.push_message(queue::AWSQueueService;
        attributes::Dict{AbstractString,
            Union{AbstractString, Number, Array{UInt8, 1}}} = Dict{AbstractString,
            Union{AbstractString, Number, Array{UInt8, 1}}}(),
        message_body::AbstractString = "")
    message_attributes = nothing
    if !isempty(attributes)
        message_attributes = map(to_SQS_attribute, attributes)
    end
    send_response = AWS.SQS.SendMessage(queue.env; queueUrl = queue.url, messageBody =
        message_body, messageAttributeSet=message_attributes)

    if send_response.http_code != 200
        error("Unable to send message $message_body to $queue")
    end

    return true
end

end # module AWSQueue
