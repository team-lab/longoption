#!/bin/bash

set -e

PWD=$(dirname $0)

#./test.sh

if [ "$OS" == "Windows_NT" ];then
  mkdir -p /tmp/longoption_test
  for i in $(ls $PWD)
  do
    cat $PWD/$i | tr -d \\r > /tmp/longoption_test/$i
  done
  chmod +x /tmp/longoption_test/*.sh
  PWD=$(cd /tmp/longoption_test && pwd -W)
fi

for v in $@
do
  echo $v
  docker run \
    -v $PWD:/test \
    --rm \
    ko1nksm/bash:$v \
    //test/test.sh
  echo Bash version $v OK
done

