# Host-side unit tests.
#
# Only for code that can be exercised without the game: no ISO, no renderer, no
# device. The guide converter qualifies — it is a pure string-to-document
# transform — which is why it is first.
#
# gtest comes from aurora, which already fetches it for its own tests, so this
# adds no new dependency.

cmake_minimum_required(VERSION 3.25)
if (CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(dusklight_host_tests LANGUAGES CXX)
  set(CMAKE_CXX_STANDARD 20)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  if (MSVC)
    add_compile_options(/MP1 /Zc:__cplusplus)
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  endif ()
  enable_testing()
  include(FetchContent)
  # Same version and digest as the exact official Aurora pin's test project.
  FetchContent_Declare(googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.17.0.tar.gz
    URL_HASH SHA256=65fab701d9829d38cb77c14acdc431d2108bfdbf8979e40eb8ae567edf10b27c
    DOWNLOAD_EXTRACT_TIMESTAMP FALSE)
  FetchContent_MakeAvailable(googletest)
endif ()
include(GoogleTest)

if (NOT TARGET gtest)
  message(STATUS "dusklight: gtest unavailable, skipping tests")
  return()
endif ()

# Compiled directly rather than linked against the game: convert.cpp depends on
# nothing but guide_doc.hpp and the standard library, and linking the real
# target would drag in the whole engine for a string transform.
add_executable(dusk_guide_tests
  guide_convert_test.cpp
  ../src/dusk/guide/convert.cpp
)
target_include_directories(dusk_guide_tests PRIVATE ../src ../include)
target_link_libraries(dusk_guide_tests PRIVATE gtest gtest_main)

# Optional check against a page actually saved from the in-app browser. Real
# pages are not committed — they are third-party content — so point this at one
# locally if you want the coverage:
#   cmake -DGUIDE_TEST_PAGE=/path/to/saved.html ...
if (DEFINED GUIDE_TEST_PAGE AND EXISTS "${GUIDE_TEST_PAGE}")
  target_compile_definitions(dusk_guide_tests PRIVATE GUIDE_TEST_PAGE="${GUIDE_TEST_PAGE}")
endif ()

gtest_discover_tests(dusk_guide_tests)

add_executable(dusk_release_version_tests
  release_version_test.cpp
  ../src/dusk/release_version.cpp
)
target_include_directories(dusk_release_version_tests PRIVATE ../src ../include)
target_link_libraries(dusk_release_version_tests PRIVATE gtest gtest_main)
gtest_discover_tests(dusk_release_version_tests)
