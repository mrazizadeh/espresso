if(EXISTS ${MPIEXEC})
  # OpenMPI 3.0 and higher checks the number of processes against the number of CPUs
  execute_process(COMMAND ${MPIEXEC} --version RESULT_VARIABLE mpi_version_result OUTPUT_VARIABLE mpi_version_output ERROR_VARIABLE mpi_version_output)
  if (mpi_version_result EQUAL 0 AND mpi_version_output MATCHES "\\(Open(RTE| MPI)\\) ([3-9]\\.|1[0-9])")
    set(MPIEXEC_OVERSUBSCRIBE "-oversubscribe")
  else()
    set(MPIEXEC_OVERSUBSCRIBE "")
  endif()
endif()

# unit_test function
function(UNIT_TEST)
  cmake_parse_arguments(TEST "" "NAME;NUM_PROC" "SRC;DEPENDS" ${ARGN})
  add_executable(${TEST_NAME} ${TEST_SRC})
  # Build tests only when testing
  set_target_properties(${TEST_NAME} PROPERTIES EXCLUDE_FROM_ALL ON)
  target_link_libraries(${TEST_NAME} PRIVATE Boost::unit_test_framework)
  if(TEST_DEPENDS)
    target_link_libraries(${TEST_NAME} PRIVATE ${TEST_DEPENDS})
  endif()
  if(WITH_COVERAGE)
    target_compile_options(${TEST_NAME} PUBLIC "$<$<CONFIG:Release>:-g>")
    target_compile_options(${TEST_NAME} PUBLIC "$<$<CONFIG:Release>:-O0>")
    target_compile_options(${TEST_NAME} PUBLIC "$<$<CXX_COMPILER_ID:Clang>:-fprofile-instr-generate>")
    target_compile_options(${TEST_NAME} PUBLIC "$<$<CXX_COMPILER_ID:Clang>:-fcoverage-mapping>")
    target_compile_options(${TEST_NAME} PUBLIC "$<$<NOT:$<CXX_COMPILER_ID:Clang>>:--coverage>")
    target_compile_options(${TEST_NAME} PUBLIC "$<$<NOT:$<CXX_COMPILER_ID:Clang>>:-fprofile-arcs>")
    target_compile_options(${TEST_NAME} PUBLIC "$<$<NOT:$<CXX_COMPILER_ID:Clang>>:-ftest-coverage>")
    if (NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
      target_link_libraries(${TEST_NAME} PUBLIC gcov)
    endif()
  endif()
  target_include_directories(${TEST_NAME} PRIVATE ${CMAKE_SOURCE_DIR}/src/core)
  target_link_libraries(${TEST_NAME} PRIVATE EspressoConfig)

  # If NUM_PROC is given, set up MPI parallel test case
  if( TEST_NUM_PROC )
    if(DEFINED TEST_NP)
      if(${TEST_NUM_PROC} GREATER ${TEST_NP})
        set(TEST_NUM_PROC ${TEST_NP})
      endif()
    endif()

    add_test(${TEST_NAME} ${MPIEXEC} ${MPIEXEC_OVERSUBSCRIBE} ${MPIEXEC_NUMPROC_FLAG} ${TEST_NUM_PROC} ${MPIEXEC_PREFLAGS} ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME} ${MPIEXEC_POSTFLAGS})
  else( )
    add_test(${TEST_NAME} ${TEST_NAME})
  endif( )

  if(WARNINGS_ARE_ERRORS)
    set_tests_properties(${TEST_NAME} PROPERTIES ENVIRONMENT "UBSAN_OPTIONS=suppressions=${CMAKE_SOURCE_DIR}/tools/ubsan-suppressions.txt:halt_on_error=1:print_stacktrace=1 ASAN_OPTIONS=halt_on_error=1:detect_leaks=0 MSAN_OPTIONS=halt_on_error=1")
  endif()

  add_dependencies(check_unit_tests ${TEST_NAME})
endfunction(UNIT_TEST)
