# Copyright (C) 2020-2024 CERN and UCLouvain.
# Licensed under the GNU Lesser General Public License (version 3 or later).
# Created by: S. Roiser (Feb 2022) for the MG5aMC CUDACPP plugin.
# Further modified by: S. Roiser (2022-2024) for the MG5aMC CUDACPP plugin.

get_filename_component(basename ${CMAKE_CURRENT_SOURCE_DIR} NAME)
string(TOLOWER ${basename} targadd)

file(GLOB_RECURSE HEADERS "../*.h" CPPProcess.h)
set(SOURCES ../BridgeKernels.cc CPPProcess.cc ../CrossSectionKernels.cc
            ../MatrixElementKernels.cc ../RamboSamplingKernels.cc
            ../RandomNumberKernels.cc)

set(libname mg5amc_cxx_${targadd})
add_library(${libname} ${SOURCES} ${HEADERS})
target_include_directories(${libname} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}"
                                             "${PROJECT_SOURCE_DIR}/src"
                                             "${PROJECT_GITROOT_DIR}/tools")

set(execname check_${targadd}.exe)
add_executable(${execname} check_sa.cc)
target_link_libraries(${execname} PUBLIC mg5amc_common ${libname})
target_include_directories(${execname} PRIVATE "${PROJECT_SOURCE_DIR}/src")

# some XCode specific stuff to make the executable run
set_property(TARGET ${libname} PROPERTY XCODE_GENERATE_SCHEME TRUE)
set_property(TARGET ${execname} PROPERTY XCODE_GENERATE_SCHEME TRUE)
set_property(TARGET ${execname} PROPERTY XCODE_SCHEME_ARGUMENTS "--bridge" "8" "8" "32")
set_property(TARGET ${execname} PROPERTY XCODE_SCHEME_WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
