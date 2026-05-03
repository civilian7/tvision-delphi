cmake_minimum_required(VERSION 3.20)

project(tvision_c LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Locate tvision via vcpkg toolchain
find_package(tvision CONFIG REQUIRED)

# Choose suffix based on architecture (32 / 64)
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(TVDLL_SUFFIX "64")
else()
    set(TVDLL_SUFFIX "32")
endif()

set(DLL_NAME tvision${TVDLL_SUFFIX})

add_library(${DLL_NAME} SHARED
    src/tvision_c.cpp
)

target_include_directories(${DLL_NAME} PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_definitions(${DLL_NAME} PRIVATE TVCAPI_BUILD)

# Link against tvision and its required Win32 libs
target_link_libraries(${DLL_NAME} PRIVATE tvision::tvision)

if (WIN32)
    target_link_libraries(${DLL_NAME} PRIVATE
        user32 gdi32 advapi32 shell32
    )
endif()

if (MSVC)
    target_compile_options(${DLL_NAME} PRIVATE /W3 /utf-8 /EHsc)
    # Use static-md (DLL CRT) — matches vcpkg triplet
    set_property(TARGET ${DLL_NAME} PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
endif()

# Output to bin/ directly
set_target_properties(${DLL_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)
