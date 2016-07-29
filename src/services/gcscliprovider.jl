"""

Assuming that we are running this module directly in a google cloud machine
with the correct permissions, there is no need to authenticate
"""
module GCSCLIProvider

using ...SimpleTasks.Types

import SimpleTasks.Services.Bucket
import SimpleTasks.Services.CLIBucket

export Details

const GCS_PREFIX = `gs:/`
const GCS_COMMAND = `gsutil`

Details() = CLIBucket.Provider(GCS_PREFIX, GCS_COMMAND)

end # module GCSCLIProvider
