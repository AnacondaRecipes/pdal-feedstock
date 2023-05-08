#!/bin/bash

set -ex

echo "Building ${PKG_NAME}."

# strip std settings from conda
CXXFLAGS="${CXXFLAGS/-std=c++14/}"
CXXFLAGS="${CXXFLAGS/-std=c++11/}"
export CXXFLAGS

if [[ ${target_platform} =~ .*linux*. ]]; then
  RPATH="-Wl,-rpath-link,${PREFIX}/lib"
elif [[ ${target_platform} == osx-64 ]]; then
  RPATH="-Wl,-rpath,${PREFIX}/lib"
fi
export LDFLAGS="${LDFLAGS} -L${PREFIX}/lib ${RPATH}"

if [ "$(uname)" == "Linux" ]; then
  # need this for draco finding
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH;${PREFIX}/lib64/pkgconfig"
fi


if [ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]; then
  mkdir native; cd native;

  # Unset them as we're ok with builds that are either slow or non-portable
  unset CFLAGS
  unset CXXFLAGS

  CC=$CC_FOR_BUILD CXX=$CXX_FOR_BUILD LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX} cmake -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="x86_64" \
    ..

  export DIMBUILDER=`pwd`/bin/dimbuilder
  make dimbuilder
  cd ..
else
  export DIMBUILDER=dimbuilder

fi


rm -rf build && mkdir build && cd build || exit 1

# Generate the build files.
echo "Generating the build files..."
cmake .. ${CMAKE_ARGS} \
  -GNinja \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DCMAKE_PREFIX_PATH=$PREFIX \
  -DDIMBUILDER_EXECUTABLE=$DIMBUILDER \
  -DBUILD_PLUGIN_I3S=ON \
  -DBUILD_PLUGIN_TRAJECTORY=ON \
  -DBUILD_PLUGIN_E57=ON \
  -DBUILD_PLUGIN_PGPOINTCLOUD=ON \
  -DBUILD_PLUGIN_ICEBRIDGE=ON \
  -DBUILD_PLUGIN_NITF=ON \
  -DBUILD_PLUGIN_TILEDB=ON \
  -DBUILD_PLUGIN_HDF=ON \
  -DBUILD_PLUGIN_DRACO=ON \
  -DENABLE_CTEST=OFF \
  -DWITH_TESTS=OFF \
  -DWITH_ZLIB=ON \
  -DWITH_ZSTD=ON \
  -DWITH_LASZIP=ON \
  -DWITH_LAZPERF=ON \
  ..

# Build.
echo "Building..."
ninja -j${CPU_COUNT} || exit 1


# Installing
echo "Installing..."
ninja install || exit 1


# This will not be needed once we fix upstream.
chmod 755 $PREFIX/bin/pdal-config

ACTIVATE_DIR=$PREFIX/etc/conda/activate.d
DEACTIVATE_DIR=$PREFIX/etc/conda/deactivate.d
mkdir -p $ACTIVATE_DIR
mkdir -p $DEACTIVATE_DIR

cp $RECIPE_DIR/scripts/activate.sh $ACTIVATE_DIR/pdal-activate.sh
cp $RECIPE_DIR/scripts/deactivate.sh $DEACTIVATE_DIR/pdal-deactivate.sh

# Error free exit!
echo "Error free exit!"
exit 0
