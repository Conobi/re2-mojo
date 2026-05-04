cmake_minimum_required(VERSION 3.20)
project(libre2_mojo CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Force RE2 + abseil to build as static archives we then bundle.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# We bundle RE2 + abseil into our .so; we do not install them as system libs.
# This silences RE2's install(EXPORT ...) which otherwise fails because
# its abseil dependencies are not in any export set under FetchContent.
set(CMAKE_SKIP_INSTALL_RULES ON CACHE BOOL "" FORCE)

# Trim what RE2 + abseil build by default.
set(RE2_BUILD_TESTING        OFF CACHE BOOL "" FORCE)
set(ABSL_PROPAGATE_CXX_STD   ON  CACHE BOOL "" FORCE)
set(ABSL_BUILD_TESTING       OFF CACHE BOOL "" FORCE)
set(ABSL_USE_GOOGLETEST_HEAD OFF CACHE BOOL "" FORCE)

include(FetchContent)
FetchContent_Declare(
  absl
  GIT_REPOSITORY https://github.com/abseil/abseil-cpp.git
  GIT_TAG        20240722.0
  EXCLUDE_FROM_ALL
)
FetchContent_Declare(
  re2
  GIT_REPOSITORY https://github.com/google/re2.git
  GIT_TAG        2024-07-02
  EXCLUDE_FROM_ALL
)
FetchContent_MakeAvailable(absl re2)

add_library(re2_mojo SHARED src/libre2_mojo.cc)
target_include_directories(re2_mojo PUBLIC include)
target_link_libraries(re2_mojo PRIVATE re2)

target_compile_options(re2_mojo PRIVATE -fno-exceptions -fvisibility=hidden)
target_link_options(re2_mojo PRIVATE -Wl,--exclude-libs,ALL)

set_target_properties(re2_mojo PROPERTIES
  OUTPUT_NAME               "re2_mojo"
  VISIBILITY_INLINES_HIDDEN ON
)
