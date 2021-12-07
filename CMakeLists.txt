cmake_minimum_required (VERSION 3.5)

project(azure_blob_storage_file_upload_utility)

set (library_name azure_blob_storage_file_upload_utility)

set (CMAKE_C_STANDARD 99)
set (CMAKE_CXX_STANDARD 14)

add_library (${library_name} STATIC src/azure_blob_storage_file_upload_utility.cpp src/blob_storage_helper.hpp
                                   src/blob_storage_helper.cpp)

target_include_directories (${library_name} PUBLIC inc)

find_package (azure_c_shared_utility REQUIRED)

find_package(azure-storage-blobs-cpp CONFIG REQUIRED)

target_link_libraries (
    ${library_name}
    PUBLIC aziotsharedutil Azure::azure-storage-blobs Azure::azure-core)

set(AZURE_BLOB_STORAGE_UTILITY_VERSION_MAJOR 0)
set(AZURE_BLOB_STORAGE_UTILITY_VERSION_MINOR 1)
set(AZURE_BLOB_STORAGE_UTILITY_VERSION_REVISION 0)

install(DIRECTORY inc/ DESTINATION include)

install(TARGETS ${library_name} 
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin)
