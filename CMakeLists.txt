cmake_minimum_required(VERSION 3.3)

include(ProcessorCount)
ProcessorCount(conc)

add_subdirectory(xorcrypt)
add_subdirectory(debruijn)
add_subdirectory(portapty)

add_custom_target(hashcat ALL
  COMMAND make -j ${conc}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/hashcat
  USES_TERMINAL
)

add_custom_target(hashcat-clear
  COMMAND make clean
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/hashcat
  USES_TERMINAL
)

install(CODE "execute_process(COMMAND make install WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/hashcat)")

add_custom_target(clear
  COMMAND ${CMAKE_MAKE_PROGRAM} clean
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/hashcat
  DEPENDS hashcat-clear
)
