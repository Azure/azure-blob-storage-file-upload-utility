/**
 * @file azure_blob_storage_file_upload_utility.cpp
 * @brief Implements the interface for interacting with Azure Blob Storage
 *
 * @copyright Copyright (c) 2021, Microsoft Corp.
 */

#include "azure_blob_storage_file_upload_utility.h"
#include "blob_storage_helper.hpp"

#include <azure_c_shared_utility/crt_abstractions.h>
#include <azure_c_shared_utility/strings.h>
#include <exception>
#include <string.h>

#ifdef __cplusplus
extern "C"
{ 
#endif

/**
 * @brief Uploads all the files listed in @p files using the storage information in @p blobInfo 
 * @param blobInfo struct describing the connection information
 * @param maxConcurrency the max amount of concurrent threads for storage operations
 * @param fileNames vector of STRING_HANDLEs listing the names of the files to be uploaded 
 * @param directoryPath path to the directory which holds the files listed in @p fileNames 
 * @returns true on successful upload of all files; false on any failure 
 */
_Bool AzureBlobStorageFileUploadUtility_UploadFilesToContainer(
    const BlobStorageInfo* blobInfo, const int maxConcurrency, VECTOR_HANDLE fileNames, const char* directoryPath)
{
    if (blobInfo == nullptr || maxConcurrency == 0 || fileNames == nullptr || directoryPath == nullptr)
    {
        return false;
    }

    _Bool succeeded = false;

    try
    {
        AzureBlobStorageHelper storageHelper(*blobInfo, maxConcurrency);
    
        succeeded = storageHelper.UploadFilesToContainer(
            fileNames,
            directoryPath,
            STRING_c_str(blobInfo->virtualDirectoryPath));
    }
    catch (std::exception& e)
    {
        return false;
    }
    catch (...)
    {
        return false;
    }

    return succeeded;
}

#ifdef __cplusplus
}
#endif 
