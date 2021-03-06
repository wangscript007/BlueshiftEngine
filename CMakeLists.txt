################################################################################
# Top-level CMakeLists.txt file for Blueshift Engine
################################################################################
cmake_minimum_required(VERSION 3.1)

if (COMMAND cmake_policy)
    if (POLICY CMP0025)
        # Compiler id for Apple Clang is now AppleClang.
        cmake_policy(SET CMP0025 NEW)
    endif ()
endif ()

set(CMAKE_OBJECT_PATH_MAX 512)
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/CMake)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(CMakeDependentOption)
include(BlueshiftCommon)

option(BUILD_RUNTIME "Build Blueshift Runtime libraies" OFF)
option(BUILD_PLAYER "Build Blueshift Player executable" OFF)
option(BUILD_EDITOR "Build Blueshift Editor executable" OFF)
option(BUILD_TEST "Build test projects" OFF)

if (BUILD_RUNTIME)
    set(ROOT_PROJECT_NAME Blueshift)

    set(ENGINE_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Source CACHE STRING "engine include directory")
    set(ENGINE_LIBRARY_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Library CACHE STRING "engine library directory")
elseif (BUILD_PLAYER)
    set(ROOT_PROJECT_NAME BlueshiftPlayer)
else ()
    message(FATAL_ERROR "Neither BUILD_RUNTIME nor BUILD_PLAYER are set")
endif ()

project(${ROOT_PROJECT_NAME})

cmake_dependent_option(USE_LUAJIT "Use LuaJIT" ON "NOT IOS AND NOT ANDROID" OFF)

# Check platform
if (ANDROID)
    set(PLATFORM_ANDROID TRUE)
elseif (WIN32)
    set(PLATFORM_WINDOWS TRUE)
elseif (APPLE AND IOS)
    set(PLATFORM_IOS TRUE)
elseif (APPLE AND ${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(PLATFORM_MACOS TRUE)
elseif (UNIX)
    set(PLATFORM_LINUX TRUE)
endif ()

if (CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(ENGINE_64BIT TRUE)
endif ()

if (CMAKE_CROSSCOMPILING)
    if (IOS)
        set(ENGINE_ARCH ${IOS_ARCH})
    elseif (ANDROID)
        set(ENGINE_ARCH ${CMAKE_ANDROID_ARCH})

        include_directories(${ANDROID_SYSROOT}/usr/include/${ANDROID_HEADER_TRIPLE})
    endif ()
else ()
    if (ENGINE_64BIT)
        set(ENGINE_ARCH x86_64)
    else ()
        set(ENGINE_ARCH i386)
    endif ()
endif ()

set(VERSION_MAJOR 0 CACHE INTERNAL "Project major version number.")
set(VERSION_MINOR 6 CACHE INTERNAL "Project minor version number.")
set(VERSION_PATCH 0 CACHE INTERNAL "Project patch version number.")

string(TIMESTAMP NOW "%Y-%m-%d %H:%M:%S")
set(VERSION_DATE ${NOW} CACHE INTERNAL "Project version date")

# Advanced variables will not be displayed in any of the cmake GUIs unless the show advanced option is on.
mark_as_advanced(VERSION_MAJOR VERSION_MINOR VERSION_PATCH VERSION_DATE)

message(STATUS "Running from ${CMAKE_CURRENT_SOURCE_DIR}")

message(STATUS "Version: ${CMAKE_VERSION}")
message(STATUS "Generator: ${CMAKE_GENERATOR}")
message(STATUS "System: ${CMAKE_SYSTEM_NAME} ${CMAKE_SYSTEM_VERSION} ${CMAKE_SYSTEM_PROCESSOR}") 
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "CXX Compiler: ${CMAKE_CXX_COMPILER}")

set(CMAKE_CONFIGURATION_TYPES Debug Release Development)

# Set this variable to specify a common place where CMake should put all executable files
set(RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/Bin/${CMAKE_GENERATOR})

set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "")

# Add DEBUG, _DEBUG definition to compiler in debug build
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -DDEBUG -D_DEBUG")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -DDEBUG -D_DEBUG")

# Add DEVELOPMENT, _DEVELOPMENT definition to compiler in development build
set(CMAKE_C_FLAGS_DEVELOPMENT "${CMAKE_C_FLAGS_RELEASE} -DDEVELOPMENT -D_DEVELOPMENT")
set(CMAKE_CXX_FLAGS_DEVELOPMENT "${CMAKE_CXX_FLAGS_RELEASE} -DDEVELOPMENT -D_DEVELOPMENT")

set(CMAKE_EXE_LINKER_FLAGS_DEVELOPMENT ${CMAKE_EXE_LINKER_FLAGS_RELEASE})

################################################################################

if (NOT CMAKE_CROSSCOMPILING)
    set(USE_DESKTOP_EGL FALSE CACHE INTERNAL "Force to use EGL on desktop platform")
endif ()

if (USE_DESKTOP_EGL)
    add_definitions(-DUSE_DESKTOP_EGL)
endif ()

if (WIN32)
    # Settings for Windows
    add_definitions(-D_UNICODE -DUNICODE)
    
    set(USE_WINDOWS_OPENAL FALSE CACHE INTERNAL "Force to use OpenAL on Windows")

    if (USE_WINDOWS_OPENAL)
        add_definitions(-DUSE_WINDOWS_OPENAL)
    endif ()

    if (MSVC)
        # Enable Function-Level Linking
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /Gy")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /Gy")
    
        # Force Synchronous PDB Writes
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /FS")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /FS")
    
        # Remove RTTI
        string(REGEX REPLACE "/GR-?" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")

        #set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /LTCG")
        #set(CMAKE_STATIC_LINKER_FLAGS_RELEASE "${CMAKE_STATIC_LINKER_FLAGS_RELEASE} /LTCG")
        #set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} /LTCG")

        # Suppress warnings when linking with release library
        set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG} /NODEFAULTLIB:\"msvcrt.lib\"")
    endif ()
elseif (APPLE) 
    # Settings for macOS, iOS
    #set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu99")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14 -stdlib=libc++")

    add_compile_options("-Wno-unused-parameter")
    add_compile_options("-Wno-unused-variable")
    add_compile_options("-Wno-unused-local-typedef")
    add_compile_options("-Wno-unused-function")
    add_compile_options("-Wno-reorder")
    add_compile_options("-Wno-inconsistent-missing-override")
    add_compile_options("-Wno-tautological-undefined-compare")

    if (IOS)
        add_compile_options("-DIOS")

        set(IOS_DEPLOYMENT_TARGET 9.0)
   else ()
        set(CMAKE_OSX_SYSROOT "macosx")
        set(CMAKE_OSX_DEPLOYMENT_TARGET "10.9") # 10.9 Mavericks
        #set(CMAKE_OSX_ARCHITECTURES "$(ARCHS_STANDARD_64_BIT)")
    endif ()
elseif (ANDROID)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14")
    #set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=gnu++14 -fno-exceptions -fno-rtti")

    # Settings for Android
    add_compile_options("-DANDROID")

    add_compile_options("-Wno-unused-parameter")
    add_compile_options("-Wno-unused-variable")
    add_compile_options("-Wno-unused-local-typedef")
    add_compile_options("-Wno-unused-function")
    add_compile_options("-Wno-unused-private-field")
    add_compile_options("-Wno-reorder")
    add_compile_options("-Wno-inconsistent-missing-override")
    add_compile_options("-Wparentheses-equality")
    add_compile_options("-Wlogical-not-parentheses")
    add_compile_options("-Wshift-overflow")
    add_compile_options("-Wno-tautological-undefined-compare")
endif ()

################################################################################

if (XAMARIN)
    if (MSVC)
        set(ENGINE_BUILD_PLATFORM_DIR "XamarinWin64")
    endif ()

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D__XAMARIN__")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D__XAMARIN__")
else ()
    if (MSVC)
        set(ENGINE_BUILD_PLATFORM_DIR "Win64")
    elseif (ANDROID)
        set(ENGINE_BUILD_PLATFORM_DIR "Android/${CMAKE_BUILD_TYPE}/${ANDROID_ABI}")
    elseif (APPLE)
        if (IOS)
            set(ENGINE_BUILD_PLATFORM_DIR "iOS$(EFFECTIVE_PLATFORM_NAME)")
        else ()
            set(ENGINE_BUILD_PLATFORM_DIR "macOS")
        endif ()
    else ()
        set(ENGINE_BUILD_PLATFORM_DIR ${CMAKE_GENERATOR})
    endif ()
endif ()

if (USE_LUAJIT)
    add_definitions(-DUSE_LUAJIT=1)
else ()
    add_definitions(-DUSE_LUAJIT=0)
endif ()

################################################################################
# Print C/CXX FLAGS
################################################################################

set(FLAGS
    CMAKE_C_FLAGS
    CMAKE_C_FLAGS_DEBUG
    CMAKE_C_FLAGS_RELEASE
    CMAKE_C_FLAGS_RELWITHDEBINFO
    CMAKE_CXX_FLAGS
    CMAKE_CXX_FLAGS_DEBUG
    CMAKE_CXX_FLAGS_RELEASE
    CMAKE_CXX_FLAGS_RELWITHDEBINFO
)

foreach(FLAG ${FLAGS})
    message(STATUS "${FLAG}: ${${FLAG}}")
endforeach()

################################################################################
# Sub projects
################################################################################
if (BUILD_RUNTIME)
    # Override subdirectory options
    set(JSONCPP_WITH_TESTS OFF CACHE "" INTERNAL FORCE)
    set(JSONCPP_WITH_POST_BUILD_UNITTEST OFF CACHE "" INTERNAL FORCE)
    set(JSONCPP_WITH_PKGCONFIG_SUPPORT OFF CACHE "" INTERNAL FORCE)

    add_subdirectory(Source/ThirdParty/zlib)
    add_subdirectory(Source/ThirdParty/minizip)
    add_subdirectory(Source/ThirdParty/libjpeg)
    add_subdirectory(Source/ThirdParty/libpng)
    add_subdirectory(Source/ThirdParty/libpvrt)
    add_subdirectory(Source/ThirdParty/etcpack)
    add_subdirectory(Source/ThirdParty/etc2comp)
    add_subdirectory(Source/ThirdParty/freetype)
    add_subdirectory(Source/ThirdParty/libogg)
    add_subdirectory(Source/ThirdParty/libvorbis)
    add_subdirectory(Source/ThirdParty/jsoncpp)
    add_subdirectory(Source/ThirdParty/tinyxml2)
    add_subdirectory(Source/ThirdParty/NvTriStrip)
    add_subdirectory(Source/ThirdParty/Bullet)
    add_subdirectory(Source/ThirdParty/HACD)
 
    if (USE_LUAJIT)
        add_subdirectory(Source/ThirdParty/luaJIT)
    else ()
        add_subdirectory(Source/ThirdParty/lua)
    endif ()
  
    add_subdirectory(Source/ThirdParty/luasocket)
    add_subdirectory(Source/ThirdParty/LuaCpp)
  
    add_subdirectory(Source/Runtime)

    add_subdirectory(Shaders)
endif ()

if (BUILD_PLAYER)
    add_subdirectory(Source/Player)
endif ()

if (BUILD_EDITOR)
    add_subdirectory(Source/ThirdParty/mikktspace)
    add_subdirectory(Source/ThirdParty/ToolWindowManager)
    add_subdirectory(Source/Editor)
endif ()

if (BUILD_TEST)
    if (NOT ANDROID)
        add_subdirectory(Source/TestBase)
    endif ()
    add_subdirectory(Source/TestRenderer)
endif ()

if (MSVC)
    if (BUILD_EDITOR)
        set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT BlueshiftEditor)
    elseif (BUILD_PLAYER)
        set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT BlueshiftPlayer)
    endif ()
endif ()

