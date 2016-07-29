module TestServices

import SimpleTasks.Services.Cache
import SimpleTasks.Services.FileSystemCache

export TEST_BASE_DIRECTORY, make_valid_file_system_cache
const TEST_BASE_DIRECTORY = "/var/tmp"
function make_valid_file_system_cache()
    return FileSystemCache.FileSystemCacheService(TEST_BASE_DIRECTORY)
end

end # module TestServices
