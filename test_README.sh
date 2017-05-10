#!/bin/bash

set -e -u
cd $(dirname $0)

EXPECTS=$1
README_FILE=$2
SUCCESS=0
FAILS=0

function do_script
{
  local script="$1"
  set --
  set +e +u
  eval "$script"
  local ret=$?
  set -e -u
  return $ret
}

LINENUM=0
IN_SCRIPT=
SCRIPT=
PATH=.:$PATH
README=$(mktemp)
cat $README_FILE|tr -d \\r >$README
exec <$README
while read line
do
  LINENUM=$((LINENUM + 1))
  if [[ ! -z "$IN_SCRIPT" ]];then
    if [[ "$line" == '```' ]];then
      case "$IN_SCRIPT" in
      text)
        if [[ ! -z "$COMPARE_RESULT" ]];then
          if [ ${BASH_VERSINFO[0]} -lt 4 ];then
            EXPECTED=$(echo "$SCRIPT"|sed -e '/ *# only bash 4$/d')
          else
            EXPECTED=$(echo "$SCRIPT"|sed -e 's/ *# only bash 4$//')
          fi
          EXPECT=
          if [[ "$COMPARE_RESULT" != "$EXPECTED" ]];then
            echo "-- $SCRIPT_NAME ---------------------------------------------"
            echo "ERROR RESULT NOT EXPECT"
            echo "$BASH_SCRIPT"
            diff -u <(echo "$COMPARE_RESULT") <(echo "$EXPECTED")
            FAILS=$((FAILS + 1))
            SUCCESS=$((SUCCESS - 1))
          else
            echo "EXPECTED RESULT $SCRIPT_NAME"
          fi
        fi
        RESULT=
        ;;
      bash)
        set +e
        RESULT=$(do_script "$SCRIPT")
        ERRORCODE=$?
        set -e
        SUCCESS=$((SUCCESS + 1))
        if [ $ERRORCODE != 0 ];then
           echo "-- $SCRIPT_NAME -------------------------------------------"
           echo ERROR $ERRORCODE
           echo "$SCRIPT"
           echo "-- STDOUT ----------------------"
           echo "$RESULT"
           RESULT=
           FAILS=$((FAILS + 1))
           SUCCESS=$((SUCCESS - 1))
        else
          echo RUN SUCCSSS $SCRIPT_NAME
        fi
        ;;
      *)
        echo "UN EXPECTED IN_SCRIPT $IN_SCRIPT"
        exit -1
      esac
      COMPARE_RESULT=
      IN_SCRIPT=
    else
      if [[ "$SCRIPT" == "1" ]];then
        SCRIPT="$line"
      else
        SCRIPT="$SCRIPT
$line"
      fi
    fi
  else
    case "$line" in
    '```bash')
      IN_SCRIPT="bash"
      SCRIPT_NAME="$README_FILE:$LINENUM"
      SCRIPT="1"
      ;;
    '↓')
      COMPARE_RESULT="$RESULT"
      BASH_SCRIPT="$SCRIPT"
      ;;
    '```')
      IN_SCRIPT="text"
      SCRIPT="1"
      ;;
    esac
  fi
done
rm $README

if [ $FAILS != 0 ];then
  echo "FAILS $FAILS"
  exit -1
else
  if [ $EXPECTS != $SUCCESS ];then
    echo "ERROR EXPECTED TESTS = $EXPECTS, BUT NOW SUCCESS= $SUCCESS"
    exit -1
  fi
  echo "SUCCESS $SUCCESS TESTS"
fi

