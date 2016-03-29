#!/bin/sh

AD_DIRECTORY="analog_devices"

if [ ! -d "$AD_DIRECTORY" ]; then
  mkdir $AD_DIRECTORY
  cd $AD_DIRECTORY
  git init
  git remote add -f origin https://github.com/analogdevicesinc/hdl.git
  # Configure sparse checkout
  git config core.sparseCheckout true
  # Add the specific folders for sparse checkout
  echo "library/axi_ad9361/*" >> .git/info/sparse-checkout
  echo "library/common/*" >> .git/info/sparse-checkout
  echo "library/scripts/*" >> .git/info/sparse-checkout
  echo "library/interfaces/*" >> .git/info/sparse-checkout
  # Get repo content
  git pull origin master
  # Change to the required branch
  git checkout hdl_2015_r2
  # Now make Interfaces
  echo "=========================="
  echo "Building AD Interfaces"
  cd library/interfaces/
  make
  # Make IP
  echo "=========================="
  echo "Building AD 9361 IP"
  cd ../axi_ad9361/
  make
  # Go back
  cd ../../../
fi
