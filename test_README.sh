#!/bin/bash

EXPECTS=5
SUCCESS=0
FAILS=0

LINENUM=0
IN_SCRIPT=
SCRIPT=
PATH=.:$PATH
exec <README.md
while read line
do
  LINENUM=$((LINENUM + 1))
  if [[ ! -z "$IN_SCRIPT" ]];then
    if [[ "$line" == '```' ]];then
      case "$IN_SCRIPT" in
      text)
        if [[ ! -z "$COMPARE_RESULT" ]];then
          if [[ "$COMPARE_RESULT" != "$SCRIPT" ]];then
            echo "-- $SCRIPT_NAME ---------------------------------------------"
            echo "ERROR RESULT NOT EXPECT"
            echo "$BASH_SCRIPT"
            diff -u <(echo "$COMPARE_RESULT") <(echo "$SCRIPT")
            FAILS=$((FAILS + 1))
            SUCCESS=$((SUCCESS - 1))
          fi
        fi
        RESULT=
        ;;
      bash)
        RESULT=$(eval "$SCRIPT")
        ERRORCODE=$?
        SUCCESS=$((SUCCESS + 1))
        if [ $ERRORCODE != 0 ];then
           echo "-- $SCRIPT_NAME -------------------------------------------"
           echo ERROR $ERRORCODE
           echo "$SCRIPT"
           RESULT=
           FAILS=$((FAILS + 1))
           SUCCESS=$((SUCCESS - 1))
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
      SCRIPT_NAME="README.md:$LINENUM"
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


if [ $FAILS != 0 ];then
  echo "FAILS $FAILS"
  exit -1
else
  if [ $EXPECTS != $SUCCESS ];then
    "ERROR EXPECTED TESTS = $EXPECTS, BUT NOW SUCCESS= $SUCCESS"
    exit -1
  fi
  echo "SUCCESS $SUCCESS TESTS"
fi

