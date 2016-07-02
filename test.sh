#!/bin/bash
set -e
cd $(dirname $0)
/bin/bash --version
./test_longoption.sh
./test_README.sh

