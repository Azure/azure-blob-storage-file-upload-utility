/**
 * @file azure_blob_storage_file_upload_utility.h
 * @brief Defines the interface for interacting with Azure Blob Storage
 *
 * @copyright Copyright (c) 2021, Microsoft Corp.
 */
#ifndef AZURE_BLOB_STORAGE_FILE_UPLOAD_UTILITY_H
#define AZURE_BLOB_STORAGE_FILE_UPLOAD_UTILITY_H

#include <azure_c_shared_utility/strings.h>
#include <azure_c_shared_utility/vector.h>
#include <stdbool.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C"
{ 
 
#endif

/**
 * @brief Struct that contains the information for uploading a set of blobs to Azure Blob Storage
 */
typedef struct tagBlobStorageInfo
{
    STRING_HANDLE
    virtualDirectoryPath; //!< Virtual hierarchy for the blobs
    STRING_HANDLE storageSasCredential; //!< Combined SAS URI and SAS Token for connecting to storage
} BlobStorageInfo;

_Bool AzureBlobStorageFileUploadUtility_UploadFilesToContainer(
    const BlobStorageInfo* blobInfo, const int maxConcurrency, VECTOR_HANDLE fileNames, const char* directoryPath);

#ifdef __cplusplus
}
#endif 

#endif // AZURE_BLOB_STORAGE_FILE_UPLOAD_UTILITY_H
