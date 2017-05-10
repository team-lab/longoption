#!/bin/bash
set -e -x
cd $(dirname $0)
/bin/bash --version
./test_longoption.sh
./test_README.sh 7 ./README.md
./test_README.sh 8 ./README.ja.md
 
