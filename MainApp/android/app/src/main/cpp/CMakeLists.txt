cmake_minimum_required(VERSION 3.22.1)
project(bliss_node_bridge LANGUAGES CXX)

add_library(node SHARED IMPORTED)
set_target_properties(node PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libnode.so")

add_library(bliss_node_bridge SHARED node_runtime_bridge.cpp)
target_include_directories(bliss_node_bridge PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/node-runtime/include/node")
target_compile_features(bliss_node_bridge PRIVATE cxx_std_20)
target_compile_options(bliss_node_bridge PRIVATE -fexceptions -frtti)
target_link_libraries(bliss_node_bridge PRIVATE node log android dl m)
