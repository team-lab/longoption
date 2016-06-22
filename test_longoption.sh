#!/bin/bash

set -e
COMMAND=$(dirname $0)/longoption.sh
FAILS=()
TESTS=0
hr=--------------------------------------------
optest(){
  local TITLE=$1
  TESTS=$((TESTS + 1))
  echo "TEST $TESTS: $TITLE"
  local TEMP=$(mktemp)
  local DOC=$2
  local COMMAND=$3
  local ACTUAL="$4"
  local EXPECT="$5"
  local EXPECT_DOT="$EXPECT
."  
  echo "#!/bin/bash
set -e
set -o pipefail
RESULT=\$(echo $(printf %q "$DOC")|$COMMAND)
eval \"\$RESULT\"
cat <<__ACTUAL__
$ACTUAL
__ACTUAL__
echo \".\"
" > $TEMP
  if ! RESULT="$(bash $TEMP)";then
    cat $TEMP
    FAILS=("${FAILS[@]}" "$TESTS [ERROR] $TITLE")
    echo "$TESTS ERROR END $TITLE"
    echo $hr
    return
    #exit -1
  fi
  if [ "$RESULT" != "$EXPECT_DOT" ];then
    echo "***************fail****************"
    echo "$DOC"
    echo "----COMMAND-----"
    echo "$COMMAND"
    echo "----SCRIPT-----"
    echo "$(cat $TEMP)"
    echo "----expect--------"
    echo "$EXPECT_DOT"
    echo "----RESULT--------"
    echo "${RESULT}"
    echo "----RESULT-INTERNAL-------"
    I=$(echo "$DOC"|bash -c "$COMMAND")
    echo "$I"
    echo "----diff--------"
    set +e
    diff -u <(echo "$EXPECT_DOT") <(echo "$RESULT")
    echo "NOT ACTUAL $TITLE"
    echo $hr
    FAILS=("${FAILS[@]}" "$TESTS [NOT ACTUAL] $TITLE")
  fi
}


DOC="
 --hogehoge HOGE オプション
 OPTPARSE: --hoge HOGE hogehoge のショートオプション的な
 --hugahuga FUGA
  --opt1 HUGE オプション HUGE
  --flag-1 フラグ
  --no-flag-2 反転フラグ
  --flag-3 flag(小文字ならオプションとして反応しないのでフラグ扱い)
  --no-flag-4 反転フラグ
"

optest "DOC で指定した変数が取れる" \
 "--opt VALNAME" "$COMMAND --opt val" 'VALNAME=$VALNAME' 'VALNAME=val'

if [ ${BASH_VERSINFO[0]} -ge 4 ];then
optest "OPTPARSE__OPTION_ARGS にオプションとして解析できた変数名が配列として入っている" \
 "--hoge HOGE" "$COMMAND --hoge val" '${OPTPARSE__OPTION_ARGS["HOGE"]}' "--hoge val"
fi

optest "IMPORTテスト OPTPARSE_IMPORT=1 ならIMPORT する" \
 "--hugahuga FUGA" "OPTPARSE_IMPORT=1 FUGA=import $COMMAND" '$FUGA' "import"

optest "IMPORTテスト OPTPARSE_IMPORT=0 ならIMPORT しない" \
 "--hugahuga FUGA" "OPTPARSE_IMPORT=0 FUGA=import $COMMAND" '$FUGA' ""

optest "IMPORTテスト OPTPARSE_IMPORT 未指定ならIMPORT しない" \
 "--hugahuga FUGA" "FUGA=import $COMMAND" '$FUGA' ""

optest "PREFIXテスト OPTPARSE_PREFIX=hoge" \
 "$DOC" "OPTPARSE_PREFIX=hoge_ $COMMAND --hogehoge 1" '
hoge_HOGE=$hoge_HOGE
HOGE=$HOGE
' "
hoge_HOGE=1
HOGE=
"
optest "PREFIX と IMPORTテスト。 IMPORTされるのは PREFIX のついた方" \
 "$DOC" "OPTPARSE_IMPORT=1 HOGE=1 hoge_HOGE=2 OPTPARSE_PREFIX=hoge_ $COMMAND" '
hoge_HOGE=$hoge_HOGE
HOGE=$HOGE
' "
hoge_HOGE=2
HOGE=
"


optest "STOP_PARSE, START_PARSE" \
 "test
  --flag1
OPTPARSE:STOP_PARSE
  --flag2
OPTPARSE:START_PARSE
  --flag3
" "$COMMAND --flag1 --flag2 --flag3" '
FLAG1=$FLAG1
FLAG2=$FLAG2
FLAG3=$FLAG3
--help--
$OPTPARSE__HELP_TEXT
' "
FLAG1=1
FLAG2=
FLAG3=1
--help--
test
  --flag1
  --flag2
  --flag3

"

optest "STOP_HELP, START_HELP" \
 "test
  --flag1
OPTPARSE:STOP_HELP
  --flag2
OPTPARSE:START_HELP
  --flag3
" "$COMMAND --flag1 --flag2 --flag3" '
FLAG1=$FLAG1
FLAG2=$FLAG2
FLAG3=$FLAG3
--help--
$OPTPARSE__HELP_TEXT
' "
FLAG1=1
FLAG2=1
FLAG3=1
--help--
test
  --flag1
  --flag3

"

optest "引数付きオプションに引数が無い場合にエラーにならない" \
 "
--hoge HOGE
--huge HUGE
" "$COMMAND --hoge hoge --huge" '
HOGE=$HOGE
HUGE=$HUGE
OPTPARSE__OTHER_ARGS=${OPTPARSE__OTHER_ARGS[*]}
' "
HOGE=hoge
HUGE=
OPTPARSE__OTHER_ARGS=--huge
"

optest "空白もうまく渡せる" \
  " --hoge HOGE " "$COMMAND --hoge \" h \" \" a \" \" b \"" '
HOGE=[$HOGE]
OPTPARSE__OTHER_ARGS0=[${OPTPARSE__OTHER_ARGS[0]}]
OPTPARSE__OTHER_ARGS1=[${OPTPARSE__OTHER_ARGS[1]}]
' "
HOGE=[ h ]
OPTPARSE__OTHER_ARGS0=[ a ]
OPTPARSE__OTHER_ARGS1=[ b ]
"

if [ ${BASH_VERSINFO[0]} -ge 4 ];then
optest "空白もうまく渡せる(OPTPARSE__OPTION_ARGS)" \
  " --hoge HOGE " "$COMMAND --hoge \" h \" \" a \" \" b \"" '
OPTPARSE__OPTION_ARGS[HOGE]=[${OPTPARSE__OPTION_ARGS["HOGE"]}]
' "
OPTPARSE__OPTION_ARGS[HOGE]=[--hoge \ h\ ]
"
fi

optest "長いテスト" \
  "$DOC" "OPTPARSE_IMPORT=1 FUGA=import $COMMAND --flag-1 --flag-2 --hogehoge \"aaa \$ \\\" bb\" arg1 arg2" '
hogehoge=$HOGE
hugahuga=$FUGA
flag-1=$FLAG_1
flag-2=$FLAG_2
flag-3=$FLAG_3
flag-4=$FLAG_4
OPTPARSE__OTHER_ARGS=${OPTPARSE__OTHER_ARGS[@]}
' '
hogehoge=aaa $ " bb
hugahuga=import
flag-1=1
flag-2=1
flag-3=0
flag-4=1
OPTPARSE__OTHER_ARGS=arg1 arg2
'

echo $hr
echo "TEST RUN $TESTS"
if [[ "${#FAILS[@]}" = 0 ]];then
  echo "ALL SUCCESS"
else
  echo "FAIL ${#FAILS[@]}"
  for i in "${FAILS[@]}"
  do
    echo "  $i"
  done
  exit -1
fi
