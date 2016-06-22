#!/bin/bash

set -e
COMMAND=$(dirname $0)/longoption.sh
optest(){
  local TEMP=$(mktemp)
  local DOC=$1
  local COMMAND=$2
  local ACTUAL="$3"
  local EXPECT="$4"
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
    exit -1
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
    diff -u <(echo "$EXPECT_DOT") <(echo "$RESULT")
  else
    echo "ok"
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


echo "OPTPARSE__OPTION_ARGS にオプションとして解析できた変数名が配列として入っている"
optest "--hoge HOGE" "$COMMAND --hoge val" '${OPTPARSE__OPTION_ARGS["HOGE"]}' "--hoge val"

echo "IMPORTテスト 未指定ならIMPORT する"
optest "$DOC" "OPTPARSE_IMPORT=1 FUGA=import $COMMAND" '$FUGA' "import"

echo "IMPORTテスト OPTPARSE_IMPORT=0 ならIMPORT しない"
optest "$DOC" "OPTPARSE_IMPORT=0 FUGA=import $COMMAND" '$FUGA' ""

echo "IMPORTテスト OPTPARSE_IMPORT 未指定ならIMPORT しない"
optest "$DOC" "FUGA=import $COMMAND" '$FUGA' ""

echo "PREFIXテスト OPTPARSE_PREFIX=hoge"
optest "$DOC" "OPTPARSE_PREFIX=hoge_ $COMMAND --hogehoge 1" '
hoge_HOGE=$hoge_HOGE
HOGE=$HOGE
' "
hoge_HOGE=1
HOGE=
"
echo "PREFIX と IMPORTテスト。 IMPORTされるのは PREFIX のついた方"
optest "$DOC" "OPTPARSE_IMPORT=1 HOGE=1 hoge_HOGE=2 OPTPARSE_PREFIX=hoge_ $COMMAND" '
hoge_HOGE=$hoge_HOGE
HOGE=$HOGE
' "
hoge_HOGE=2
HOGE=
"


echo "STOP_PARSE, START_PARSE"
optest "test
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

echo "STOP_HELP, START_HELP"
optest "test
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

echo "引数付きオプションに引数が無い場合にエラーにならない"
optest "
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

echo "空白もうまく渡せる"
optest " --hoge HOGE " "$COMMAND --hoge \" h \" \" a \" \" b \"" '
HOGE=[$HOGE]
OPTPARSE__OTHER_ARGS0=[${OPTPARSE__OTHER_ARGS[0]}]
OPTPARSE__OTHER_ARGS1=[${OPTPARSE__OTHER_ARGS[1]}]
OPTPARSE__OPTION_ARGS[HOGE]=[${OPTPARSE__OPTION_ARGS["HOGE"]}]
' "
HOGE=[ h ]
OPTPARSE__OTHER_ARGS0=[ a ]
OPTPARSE__OTHER_ARGS1=[ b ]
OPTPARSE__OPTION_ARGS[HOGE]=[--hoge \ h\ ]
"
echo "長いテスト"
optest "$DOC" "OPTPARSE_IMPORT=1 FUGA=import $COMMAND --flag-1 --flag-2 --hogehoge \"aaa \$ \\\" bb\" arg1 arg2" '
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
