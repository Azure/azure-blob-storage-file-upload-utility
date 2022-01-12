#!/bin/bash

# install-deps.sh makes it more convenient to install
# dependencies for the Azure Blob Storage File Upload Utility.
# Some dependencies are installed via packages and
# others are installed from source code.

# Ensure that getopt starts from first option if ". <script.sh>" was used.
OPTIND=1

# Ensure we dont end the user's terminal session if invoked from source (".").
if [[ $0 != "${BASH_SOURCE[0]}" ]]; then
    ret=return
else
    ret=exit
fi

# Use sudo if user is not root
SUDO=""
if [ "$(id -u)" != "0" ]; then
    SUDO="sudo"
fi

warn() { echo -e "\033[1;33mWarning:\033[0m $*" >&2; }

error() { echo -e "\033[1;31mError:\033[0m $*" >&2; }

# Setup defaults
install_all_deps=false
install_packages=false
install_packages_only=false
# The folder where source code will be placed
# for building and installing from source.
work_folder=/tmp
keep_source_code=false
use_ssh=false

# Utility Deps
install_abs_file_upload_utility_deps=false

skip_azure_iot_sdk_install=false
install_azure_iot_sdk=false
azure_sdk_ref=main

install_azure_storage_sdk=false
azure_storage_sdk_ref=main

# Dependencies packages
abs_utils_packages=('git' 'make' 'snap' 'build-essential' 'ninja-build' 'libcurl4-openssl-dev' 'uuid-dev' 'libssl-dev' 'lsb-release' 'curl' 'libxml2-dev' 'wget')
compiler_packages=("gcc-[68]")

print_help() {
    echo "Usage: install-deps.sh [options...]"
    echo "-a, --install-all-deps    Install all dependencies."
    echo "                          Implies --install-azure-blob-storage-deps and --install-packages."
    echo "                          Can be used with --install-packages-only."
    echo "                          This is the default if no options are specified."
    echo ""
    echo "--install-azure-blob-storage-deps  Install dependencies for the Azure Blob Storage Utility"
    echo "                                   Implies --install-azure-iot-sdk, --install-azure-storage-sdk, and --install-catch2."
    echo "                                   When used with --install-packages will also install the package dependencies."
    echo "--skip-azure-iot-sdk-install Skips the installation of the Azure IoT C SDK."
    echo "                             Used when the caller knows the Azure IoT C SDK has already been installed."
    echo "--install-azure-iot-sdk   Install the Azure IoT C SDK from source."
    echo "--azure-iot-sdk-ref <ref> Install the Azure IoT C SDK from a specific branch or tag."
    echo "                          Default is public-preview."
    echo "--install-azure-storage-sdk   Install the Azure C++ Lite Blob Storage SDK from source."
    echo "--azure-storage-sdk-ref <ref> Install the Azure C++ Lite Blob Storage SDK from a specific branch or tag."
    echo ""
    echo "-p, --install-packages    Indicates that packages should be installed."
    echo ""
    echo "--install-packages-only   Indicates that only packages should be installed and that dependencies should not be installed from source."
    echo ""
    echo "-f, --work-folder <work_folder>   Specifies the folder where source code will be cloned or downloaded."
    echo "                                  Default is /tmp."
    echo "-k, --keep-source-code            Indicates that source code should not be deleted after install from work_folder."
    echo ""
    echo "--use-ssh                 Use ssh URLs to clone instead of https URLs."
    echo "--list-deps               List the states of the dependencies."
    echo "-h, --help                Show this help message."
    echo ""
    echo "Example: ${BASH_SOURCE[0]} --install-all-deps --work-folder ~/azure-blob-stroage-utiltiy --keep-source-code"
}

do_install_abs_file_upload_utility_deps() {
    echo "Installing dependency packages for the Azure Blob Storage Utility Agent..."

    $SUDO apt-get install --yes "${abs_utils_packages[@]}" || return

    # The latest version of gcc available on Debian is gcc-8. We install that version if we are
    # building for Debian, otherwise we install gcc-6 for Ubuntu.
    OS=$(lsb_release --short --id)
    if [[ $OS == "Debian" ]]; then
        $SUDO apt-get install --yes gcc-8 g++-8 || return
    else
        $SUDO apt-get install --yes gcc-6 g++-6 || return
    fi

    # The following is a workaround as IoT SDK references the following paths which don't exist
    # on our target platforms, and without these folders existing, static analysis will report:
    # (information) Couldn't find path given by -I '/usr/local/inc/'
    # (information) Couldn't find path given by -I '/usr/local/pal/linux/'
    $SUDO mkdir --parents /usr/local/inc /usr/local/pal/linux
}

do_install_azure_iot_sdk() {
    echo "Installing Azure IoT C SDK ..."
    local azure_sdk_dir=$work_folder/azure-iot-sdk-c
    if [[ $keep_source_code != "true" ]]; then
        $SUDO rm -rf $azure_sdk_dir || return
    elif [[ -d $azure_sdk_dir ]]; then
        warn "$azure_sdk_dir already exists! Skipping Azure IoT C SDK."
        return 0
    fi

    local azure_sdk_url
    if [[ $use_ssh == "true" ]]; then
        azure_sdk_url=git@github.com:Azure/azure-iot-sdk-c.git
    else
        azure_sdk_url=https://github.com/Azure/azure-iot-sdk-c.git
    fi

    echo -e "Building azure-iot-sdk-c ...\n\tBranch: $azure_sdk_ref\n\tFolder: $azure_sdk_dir"
    mkdir -p $azure_sdk_dir || return
    pushd $azure_sdk_dir > /dev/null
    git clone --branch $azure_sdk_ref $azure_sdk_url . || return
    git submodule update --init || return

    mkdir cmake || return
    pushd cmake > /dev/null

    # use_http is required for uHTTP support.
    local azureiotsdkc_cmake_options=(
        "-Duse_amqp:BOOL=OFF"
        "-Duse_http:BOOL=ON"
        "-Duse_mqtt:BOOL=ON"
        "-Dskip_samples:BOOL=ON"
        "-Dbuild_service_client:BOOL=OFF"
        "-Dbuild_provisioning_service_client:BOOL=OFF"
    )

    if [[ $keep_source_code == "true" ]]; then
        # If source is wanted, presumably samples and symbols are useful as well.
        azureiotsdkc_cmake_options+=("-DCMAKE_BUILD_TYPE:STRING=Debug")
    else
        azureiotsdkc_cmake_options+=("-Dskip_samples=ON")
    fi

    cmake "${azureiotsdkc_cmake_options[@]}" .. || return

    cmake --build . || return
    $SUDO cmake --build . --target install || return

    popd > /dev/null
    popd > /dev/null

    if [[ $keep_source_code != "true" ]]; then
        $SUDO rm -rf $azure_sdk_dir || return
    fi
}

do_install_azure_storage_sdk() {
    echo "Installing azure-storage-sdk"
    local azure_storage_sdk_dir=$work_folder/azure_storage_sdk_dir

    if [[ $keep_source_code != "true" ]]; then
        $SUDO rm -rf $azure_storage_sdk_dir || return
    elif [[ -d $azure_storage_sdk_dir ]]; then
        warn "$azure_storage_sdk_dir already exists! Skipping Azure Storage SDK."
        return 0
    fi

    local azure_storage_sdk_url
    if [[ $use_ssh == "true" ]]; then
        azure_storage_sdk_url=git@github.com:Azure/azure-sdk-for-cpp.git
    else
        azure_storage_sdk_url=https://github.com/Azure/azure-sdk-for-cpp.git
    fi
    
    echo -e "Building Azure Storage SDK ...\n\tBranch: $azure_storage_sdk_ref\n\t Folder: $azure_storage_sdk_dir"
    mkdir -p $azure_storage_sdk_dir || return
    pushd $azure_storage_sdk_dir > /dev/null
    git clone --recursive --single-branch --branch $azure_storage_sdk_ref --depth 1 $azure_storage_sdk_url . || return


    mkdir cmake || return
    pushd cmake > /dev/null

    local azure_blob_storage_file_upload_utility_cmake_options
    if [[ $keep_source_code == "true" ]]; then
        # If source is wanted, presumably samples and symbols are useful as well.
        azure_blob_storage_file_upload_utility_cmake_options+=("-DCMAKE_BUILD_TYPE:STRING=Debug")
    else
        azure_blob_storage_file_upload_utility_cmake_options+=("-DCMAKE_BUILD_TYPE:STRING=Release")
    fi
    
    local architecture 
    architecture=`uname -m`
    echo "${architecture}"
    local cmake_url
    local cmake_tar_path
    local cmake_dir_path
    local cmake_build_from_source=false
    if [[ "${architecture}" == "x86_64" ]]; then
        echo "Detected x86_64 architecture"
        echo "Attempting to use existing binary for CMake"
        cmake_url="https://cmake.org/files/v3.19/cmake-3.19.8-Linux-x86_64.tar.gz"
        cmake_tar_path="./cmake-3.19.8-Linux-x86_64.tar.gz"
        cmake_dir_path="./cmake-3.19.8-Linux-x86_64/"
        cmake_build_from_source=false
    elif [ "${architecture}" == "aarch64" ]; then
        echo "Detected aarch64 architecture"
        echo "Attempting to use existing binary for CMake"
        cmake_url="https://cmake.org/files/v3.19/cmake-3.19.8-Linux-aarch64.tar.gz"
        cmake_tar_path="./cmake-3.19.8-Linux-aarch64.tar.gz"
        cmake_dir_path="./cmake-3.19.8-Linux-aarch64/"
        cmake_build_from_source=false
    else
        echo "Unknown architecture... assuming most likely arm32hf"
        echo "Attempting to build CMake from source"
        cmake_url="https://cmake.org/files/v3.21/cmake-3.21.4.tar.gz"
        cmake_tar_path="./cmake-3.21.4.tar.gz"
        cmake_dir_path="./cmake-3.21.4/"
        cmake_build_from_source=true
        exit 1
    fi

    wget ${cmake_url}  > /dev/null
    tar -zxvf ${cmake_tar_path} > /dev/null

    if [[ $cmake_build_from_source == "true"  ]]; then
        echo "Building CMake from source."
        pushd $cmake_dir_path > /dev/null
        ./bootstrap > /dev/null  
        make > /dev/null
        popd > /dev/null   
    fi
    
    ${cmake_dir_path}/bin/cmake "${azure_blob_storage_file_upload_utility_cmake_options[@]}" .. || return

    ${cmake_dir_path}/bin/cmake --build . || return
    $SUDO ${cmake_dir_path}/bin/cmake --build . --target install || return

    rm -fr ${cmake_dir_path}
    rm -fr ${cmake_tar_path}

    popd > /dev/null
    popd > /dev/null

    if [[ $keep_source_code != "true" ]]; then
        $SUDO rm -rf $azure_storage_sdk_dir || return
    fi
}

do_list_all_deps() {
    declare -a deps_set=()
    deps_set+=(${abs_utils_packages[@]})
    deps_set+=(${compiler_packages[@]})
    echo "Listing the state of dependencies:"
    dpkg-query -W -f='${binary:Package} ${Version} (${Architecture})\n' "${deps_set[@]}"
    ret_val=$?
    if [ $ret_val -eq 1 ]; then
        warn "dpkg-query failed"
        return 0
    elif [ $ret_val -ge 2 ]; then
        error "dpkg-query failed with status $ret_val"
        return $ret_val
    fi
    return 0
}

###############################################################################

# Check if no options were specified.
if [[ $1 == "" ]]; then
    error "Must specify at least one option."
    $ret 1
fi

# Parse cmd options
while [[ $1 != "" ]]; do
    case $1 in
    -a | --install-all-deps)
        install_all_deps=true
        ;;
    --install-azure-blob-storage-deps)
        install_abs_file_upload_utility_deps=true
        ;;
    --install-azure-iot-sdk)
        install_azure_iot_sdk=true
        ;;
    --azure-iot-sdk-ref)
        shift
        azure_sdk_ref=$1
        ;;
    --skip-azure-iot-sdk-install)
        shift
        skip_azure_iot_sdk_install=true
        ;;
    --install-azure-storage-sdk)
        shift
        install_azure_storage_sdk=true
        ;;
    --azure-storage-sdk-ref)
        shift
        azure_storage_sdk_ref=$1
        ;;
    -p | --install-packages)
        install_packages=true
        ;;
    --install-packages-only)
        install_packages_only=true
        ;;
    -f | --work-folder)
        shift
        work_folder=$(realpath "$1")
        ;;
    -k | --keep-source-code)
        keep_source_code=true
        ;;
    --use-ssh)
        use_ssh=true
        ;;
    --list-deps)
        do_list_all_deps
        $ret $?
        ;;
    -h | --help)
        print_help
        $ret 0
        ;;
    *)
        error "Invalid argument: $*"
        $ret 1
        ;;
    esac
    shift
done

# If there is no install action specified,
# assume that we want to install all deps.
if [[ $install_all_deps != "true" && $install_abs_file_upload_utility_deps != "true" && $install_azure_iot_sdk != "true" ]]; then
    install_all_deps=true
fi

# If --all was specified,
# set all install actions to "true".
if [[ $install_all_deps == "true" ]]; then
    install_abs_file_upload_utility_deps=true
    install_packages=true
fi

# Set implied options for aduc deps.
if [[ $install_abs_file_upload_utility_deps == "true" ]]; then

    if [[ $skip_azure_iot_sdk_install == "true" ]]; then
        install_azure_iot_sdk=false
    else
        install_azure_iot_sdk=true
    fi
    install_azure_iot_sdk=true
    install_azure_storage_sdk=true
fi

# Set implied options for packages only.
if [[ $install_packages_only == "true" ]]; then
    install_packages=true
    install_azure_iot_sdk=false
fi

if [[ $install_packages == "true" ]]; then
    # Check if we need to install any packages
    # before we call apt update.
    if [[ $install_abs_file_upload_utility_deps == "true" ]]; then
        echo "Updating repository list..."
        $SUDO apt-get update --yes --fix-missing --quiet || $ret
    fi
fi

if [[ $install_abs_file_upload_utility_deps == "true" ]]; then
    do_install_abs_file_upload_utility_deps || $ret
fi

# Install dependencies from source
if [[ $install_packages_only == "false" ]]; then
    # if [[ $install_azure_iot_sdk == "true" ]]; then
    #     do_install_azure_iot_sdk || $ret
    # fi

    if [[ $install_azure_storage_sdk == "true" ]]; then
        do_install_azure_storage_sdk || $ret
    fi
fi

# After installation, it prints out the states of dependencies
if [[ $install_abs_file_upload_utility_deps == "true" || $install_packages_only == "true" || $install_packages == "true" ]]; then
    do_list_all_deps || $ret $?
fi
