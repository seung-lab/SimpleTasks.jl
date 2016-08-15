module BasicTask

export Info

"""
    BasicTask.Info

Type contains basic information for a daemon task

"""
type Info
    id::Int64                           # Numerical identifier for specific task
    name::AbstractString                # String identifer for the type of task
    base_directory::AbstractString       # Base directory for fetching input data
    inputs::Array{AbstractString, 1}    # Names of files we are fetching
end

function Info{String <: AbstractString}(dict::Dict{String, Any})
    if haskey(dict, "id")
        id = typeof(dict["id"]) <: Int ?  dict["id"] : parse(Int64, dict["id"])
    else
        id = -1
    end

    if isempty(strip(dict["name"]))
        throw(ArgumentError("Task name can not be empty"))
    end

    # parse base directory
    if isempty(strip(dict["base_directory"]))
        throw(ArgumentError("Payload does not include a base_directory"))
    end

    # parse input list
    if typeof(dict["inputs"]) != Array{Any, 1} ||
            length(dict["inputs"]) == 0
        throw(ArgumentError("Payload does not include a input list"))
    end

    return Info(id, dict["name"], dict["base_directory"], dict["inputs"])
end

end # module BasicTask
