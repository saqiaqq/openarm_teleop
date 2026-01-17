cmake_minimum_required(VERSION 3.22)
project(openarm_teleop)

find_package(ament_cmake REQUIRED)
find_package(OpenArmCAN REQUIRED)
find_package(orocos_kdl REQUIRED)
find_package(kdl_parser REQUIRED)
find_package(Eigen3 REQUIRED)
find_package(urdfdom REQUIRED)
find_package(urdfdom_headers REQUIRED)
find_package(yaml-cpp REQUIRED)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Handle yaml-cpp alias if needed
if(NOT TARGET yaml-cpp::yaml-cpp AND TARGET yaml-cpp)
  add_library(yaml-cpp::yaml-cpp ALIAS yaml-cpp)
endif()

# Handle kdl_parser target if needed
if(NOT TARGET kdl_parser::kdl_parser)
  add_library(kdl_parser::kdl_parser INTERFACE IMPORTED)
  target_link_libraries(kdl_parser::kdl_parser INTERFACE ${kdl_parser_LIBRARIES})
  target_include_directories(kdl_parser::kdl_parser INTERFACE ${kdl_parser_INCLUDE_DIRS})
endif()

# Library
add_library(openarm_teleop_lib STATIC
  src/controller/dynamics.cpp
  src/controller/control.cpp
  src/openarm_port/openarm_init.cpp
  src/openarm_port/joint_mapper.cpp
)

target_include_directories(openarm_teleop_lib PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
  $<INSTALL_INTERFACE:include>
)

# Link libraries
target_link_libraries(openarm_teleop_lib PUBLIC
  OpenArmCAN::openarm_can
  Eigen3::Eigen
  ${orocos_kdl_LIBRARIES}
  kdl_parser::kdl_parser
  urdfdom::urdfdom_model
  yaml-cpp::yaml-cpp
)

# Executables
add_executable(gravity_comp control/gravity_compasation.cpp)
target_link_libraries(gravity_comp PRIVATE openarm_teleop_lib)

add_executable(comm_test control/openarm_communication_test.cpp)
target_link_libraries(comm_test PRIVATE openarm_teleop_lib)

add_executable(unilateral_control control/openarm_unilateral_control.cpp)
target_link_libraries(unilateral_control PRIVATE openarm_teleop_lib)

add_executable(bilateral_control control/openarm_bilateral_control.cpp)
target_link_libraries(bilateral_control PRIVATE openarm_teleop_lib)

# Install
install(TARGETS
  openarm_teleop_lib
  gravity_comp
  comm_test
  unilateral_control
  bilateral_control
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION lib/${PROJECT_NAME}
)

install(DIRECTORY src/
  DESTINATION include
  FILES_MATCHING PATTERN "*.hpp" PATTERN "*.h"
)

install(PROGRAMS
  script/launch_bilateral.sh
  script/launch_grav_comp.sh
  script/launch_unilateral.sh
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()
