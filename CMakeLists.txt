cmake_minimum_required (VERSION 3.5)

project(azure_blob_storage_file_upload_utility)

set (library_name azure_blob_storage_file_upload_utility)


set (CMAKE_C_STANDARD 99)
set (CMAKE_CXX_STANDARD 14)

find_package (azure_c_shared_utility REQUIRED)
message(STATUS "CURL_FOUND=${CURL_FOUND}")

# set (CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/")

find_package(CURL REQUIRED)

find_package(azure-storage-blobs-cpp CONFIG REQUIRED)

if (NOT TARGET CURL::libcurl)
    if(CURL_INCLUDE_DIR)
        foreach(_curl_version_header curlver.h curl.h)
            if(EXISTS "${CURL_INCLUDE_DIR}/curl/${_curl_version_header}")
                file(STRINGS "${CURL_INCLUDE_DIR}/curl/${_curl_version_header}" curl_version_str REGEX "^#define[\t ]+LIBCURL_VERSION[\t ]+\".*\"")

                string(REGEX REPLACE "^#define[\t ]+LIBCURL_VERSION[\t ]+\"([^\"]*)\".*" "\\1" CURL_VERSION_STRING "${curl_version_str}")
                unset(curl_version_str)
                break()
            endif()
        endforeach()
    endif()

    add_library(CURL::libcurl UNKNOWN IMPORTED)
    set_target_properties(CURL::libcurl PROPERTIES
                            INTERFACE_INCLUDE_DIRECTORIES "${CURL_INCLUDE_DIRS}")

    if(EXISTS "${CURL_LIBRARY}")
        set_target_properties(CURL::libcurl PROPERTIES
                                IMPORTED_LINK_INTERFACE_LANGUAGES "C"
                                IMPORTED_LOCATION "${CURL_LIBRARY}")
    endif()
    set_property(TARGET CURL::libcurl APPEND PROPERTY
                    IMPORTED_CONFIGURATIONS RELEASE)
    set_target_properties(CURL::libcurl PROPERTIES
                            IMPORTED_LINK_INTERFACE_LANGUAGES "C"
                            IMPORTED_LOCATION_RELEASE "${CURL_LIBRARY_RELEASE}")
endif()

message(STATUS "CURL_FOUND=${CURL_FOUND}")

include_directories(${CURL_INCLUDE_DIRS})

set(${library_name}_target_libs ${azure_blob_storage_file_upload_utility_target_libs} ${CURL_LIBRARIES})

# add_library( CURL::libcurl IMPORT ${CURL_LIBRARIES})

add_library (${library_name} STATIC src/azure_blob_storage_file_upload_utility.cpp src/blob_storage_helper.hpp
                                   src/blob_storage_helper.cpp)

target_include_directories (${library_name} PUBLIC inc)

target_link_libraries (
    ${library_name}
    PRIVATE aziotsharedutil Azure::azure-storage-blobs Azure::azure-core ${azure_blob_storage_file_upload_utility_target_libs})

set(AZURE_BLOB_STORAGE_UTILITY_VERSION_MAJOR 0)
set(AZURE_BLOB_STORAGE_UTILITY_VERSION_MINOR 1)
set(AZURE_BLOB_STORAGE_UTILITY_VERSION_REVISION 0)

install(DIRECTORY inc/ DESTINATION include)

install(TARGETS ${library_name} 
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin)
