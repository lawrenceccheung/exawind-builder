#!bin/bash

exawind_proj_env ()
{
    echo "==> HYPRE: No additional dependencies"
}

exawind_hypre_fix_gpu ()
{
    unset OMPI_CXX
    unset EXAWIND_CUDA_WRAPPER
    unset NVCC_WRAPPER_DEFAULT_COMPILER

    export CUDA_HOME=${CUDA_HOME:-$(dirname $(dirname $(which nvcc)))}
}

exawind_cmake_base ()
{
    # Not exactly CMake, but we use this function anyway. Must be executed from
    # `hypre/src` directory

    local extra_args="$@"
    local install_dir=""
    local enable_openmp=${ENABLE_OPENMP:-OFF}
    local enable_bigint=${ENABLE_BIGINT:-ON}
    local enable_cuda=${ENABLE_CUDA:-OFF}
    local enable_uvm=${HYPRE_ENABLE_UVM:-ON}
    local openmp_args=" --without-openmp "
    local bigint_args=" --enable-bigint "
    local cuda_args=" --without-cuda "
    local uvm_args=""

    # HYPRE configure cannot handle Ninja builds, so disable any CMake
    # directives that got added
    if [[ $extra_args[0] = -G* ]] ; then
        if [[ ${#extra_args[@]} -eq 1 ]] ; then
            extra_args=""
        else
            extra_args=${extra_args[@]:1}
        fi
    fi

    if [ -n "$HYPRE_INSTALL_PREFIX" ] ; then
        install_dir="$HYPRE_INSTALL_PREFIX"
    else
        install_dir="$(cd .. && pwd)/install"
    fi

    if [ "${enable_openmp}" = "ON" ] ; then
        echo "==> HYPRE: Enabling OpenMP"
        openmp_args=" --with-openmp "
    else
        echo "==> HYPRE: Disabling OpenMP"
    fi
    if [ "${enable_cuda}" = "ON" ] ; then
        echo "==> HYPRE: Enabling CUDA"
        cuda_args=" --with-cuda "
        export HYPRE_CUDA_SM=${EXAWIND_CUDA_SM:-60}
        exawind_hypre_fix_gpu

        if [ "${enable_uvm}" = "ON" ] ; then
            uvm_args=" --enable-unified-memory "
        else
            uvm_args=" --disable-unified-memory "
        fi
    else
        echo "==> HYPRE: Disabling CUDA"
    fi

    if [ "${enable_bigint}" = "ON" ] ; then
        echo "==> HYPRE: Enabling big Integer support"
    else
        echo "==> HYPRE: Disabling big Integer support"
        bigint_args=" --disable-bigint "
    fi

    local config_cmd=(
        ./configure
        --prefix=${HYPRE_INSTALL_PREFIX}
        --without-superlu
        ${bigint_args}
        ${openmp_args}
        ${cuda_args}
        ${uvm_args}
        ${extra_args}
    )

    echo "${config_cmd[@]}"
    eval "${config_cmd[@]}"
    command make clean
}

exawind_make ()
{
    local num_tasks=${EXAWIND_NUM_JOBS:-$EXAWIND_NUM_JOBS_DEFAULT}

    if [ "$#" == "0" ] ; then
        extra_args="-j ${num_tasks}"
    else
        extra_args="$@"
    fi

    if [ "${ENABLE_CUDA:-OFF}" = "ON" ] ; then
       exawind_hypre_fix_gpu
    fi

    command make ${extra_args} 2>&1 | tee make_output.log
}
