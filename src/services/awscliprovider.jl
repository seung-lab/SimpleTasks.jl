module AWSCLIProvider

using ...SimpleTasks.Types

import AWS
import SimpleTasks.Services.Bucket
import SimpleTasks.Services.CLIBucket

export Details

const AWS_KEY_PATH = "$(homedir())/.aws/"
const AWS_KEY_FILE = "$AWS_KEY_PATH/config"
const AWS_PREFIX = `s3:/`
const AWS_COMMAND = `aws s3`

Details(env::AWS.AWSEnv) =
    create_access!(env.aws_id, env.aws_seckey) && 
    CLIBucket.Provider(AWS_PREFIX, AWS_COMMAND)

Details(aws_access_key_id::AbstractString,
    aws_secret_access_key::AbstractString) =
    create_access!(aws_access_key_id, aws_secret_access_key) && 
    CLIBucket.Provider(AWS_PREFIX, AWS_COMMAND)

function create_access!(aws_access_key_id::AbstractString,
        aws_secret_access_key::AbstractString)
    if stat(AWS_KEY_FILE).size == 0
        mkpath(AWS_KEY_PATH)
        println("No access file found for aws cli, creating one!")
        file = open(AWS_KEY_FILE, "w")
        write(file, "[default]\n")
        write(file, "aws_access_key_id = $(aws_access_key_id)\n")
        write(file, "aws_secret_access_key = $(aws_secret_access_key)\n")
        close(file)
    end
    return true
end

end # module AWSCLIProvider
