include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(firstpro_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(firstpro_setup_options)
  option(firstpro_ENABLE_HARDENING "Enable hardening" ON)
  option(firstpro_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    firstpro_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    firstpro_ENABLE_HARDENING
    OFF)

  firstpro_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR firstpro_PACKAGING_MAINTAINER_MODE)
    option(firstpro_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(firstpro_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(firstpro_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(firstpro_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(firstpro_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(firstpro_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(firstpro_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(firstpro_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(firstpro_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(firstpro_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(firstpro_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(firstpro_ENABLE_PCH "Enable precompiled headers" OFF)
    option(firstpro_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(firstpro_ENABLE_IPO "Enable IPO/LTO" ON)
    option(firstpro_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(firstpro_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(firstpro_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(firstpro_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(firstpro_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(firstpro_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(firstpro_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(firstpro_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(firstpro_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(firstpro_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(firstpro_ENABLE_PCH "Enable precompiled headers" OFF)
    option(firstpro_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      firstpro_ENABLE_IPO
      firstpro_WARNINGS_AS_ERRORS
      firstpro_ENABLE_USER_LINKER
      firstpro_ENABLE_SANITIZER_ADDRESS
      firstpro_ENABLE_SANITIZER_LEAK
      firstpro_ENABLE_SANITIZER_UNDEFINED
      firstpro_ENABLE_SANITIZER_THREAD
      firstpro_ENABLE_SANITIZER_MEMORY
      firstpro_ENABLE_UNITY_BUILD
      firstpro_ENABLE_CLANG_TIDY
      firstpro_ENABLE_CPPCHECK
      firstpro_ENABLE_COVERAGE
      firstpro_ENABLE_PCH
      firstpro_ENABLE_CACHE)
  endif()

  firstpro_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (firstpro_ENABLE_SANITIZER_ADDRESS OR firstpro_ENABLE_SANITIZER_THREAD OR firstpro_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(firstpro_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(firstpro_global_options)
  if(firstpro_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    firstpro_enable_ipo()
  endif()

  firstpro_supports_sanitizers()

  if(firstpro_ENABLE_HARDENING AND firstpro_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR firstpro_ENABLE_SANITIZER_UNDEFINED
       OR firstpro_ENABLE_SANITIZER_ADDRESS
       OR firstpro_ENABLE_SANITIZER_THREAD
       OR firstpro_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${firstpro_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${firstpro_ENABLE_SANITIZER_UNDEFINED}")
    firstpro_enable_hardening(firstpro_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(firstpro_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(firstpro_warnings INTERFACE)
  add_library(firstpro_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  firstpro_set_project_warnings(
    firstpro_warnings
    ${firstpro_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(firstpro_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    firstpro_configure_linker(firstpro_options)
  endif()

  include(cmake/Sanitizers.cmake)
  firstpro_enable_sanitizers(
    firstpro_options
    ${firstpro_ENABLE_SANITIZER_ADDRESS}
    ${firstpro_ENABLE_SANITIZER_LEAK}
    ${firstpro_ENABLE_SANITIZER_UNDEFINED}
    ${firstpro_ENABLE_SANITIZER_THREAD}
    ${firstpro_ENABLE_SANITIZER_MEMORY})

  set_target_properties(firstpro_options PROPERTIES UNITY_BUILD ${firstpro_ENABLE_UNITY_BUILD})

  if(firstpro_ENABLE_PCH)
    target_precompile_headers(
      firstpro_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(firstpro_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    firstpro_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(firstpro_ENABLE_CLANG_TIDY)
    firstpro_enable_clang_tidy(firstpro_options ${firstpro_WARNINGS_AS_ERRORS})
  endif()

  if(firstpro_ENABLE_CPPCHECK)
    firstpro_enable_cppcheck(${firstpro_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(firstpro_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    firstpro_enable_coverage(firstpro_options)
  endif()

  if(firstpro_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(firstpro_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(firstpro_ENABLE_HARDENING AND NOT firstpro_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR firstpro_ENABLE_SANITIZER_UNDEFINED
       OR firstpro_ENABLE_SANITIZER_ADDRESS
       OR firstpro_ENABLE_SANITIZER_THREAD
       OR firstpro_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    firstpro_enable_hardening(firstpro_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
