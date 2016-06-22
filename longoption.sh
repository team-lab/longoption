#!/bin/bash
#
## 引数解析器
#
#  ヘルプ用のテキストをオプション指定と見なして、引数を解析し、環境変数に突っ込みたい
#
### オプション指定 = 標準入力
#
#  標準入力をオプション指定として解析する。
#  --[-a-z0-9]+ で始まる行をオプション指定と見なす
#
#  --hoge HOGE のような形 は、引数付きオプション
#    HOGE を変数名として代入する
#    変数名として認識されるのは [A-Z0-9_]+ で、スペースで終わっていること
#    初期値は空文字
#
#  引数がつかないもの（ --hoge のような形）はフラグ指定。
#    --hoge の `hoge` 部分を大文字にして '-' を '_' に置換したものを変数名として 1 を代入する
#    フラグは --no-hoge で 0 を代入することができる
#    初期値は 0 (--no-hoge のような反転指定されている場合は初期値は 1)
#
#  オプションでもフラグでも無い行は無視される
#
#  LONGOPTION: で始まる行はヘルプに表示されない(オプション解析だけされる）
#  LONGOPTION:STOP_PARSE の行があれば、解析を中断する（ヘルプにだけ追加される）
#  LONGOPTION:START_PARSE の行があれば、解析を再開する
#  LONGOPTION:STOP_HELP の行があれば、その行以降はヘルプに表示されない（オプション解析だけされる）
#  LONGOPTION:START_HELP の行があれば、その行以降はヘルプに表示される
#
#  環境変数
#    LONGOPTION_IMPORT=1 なら、変数名と同名の環境変数が設定されていればその値を初期値とする
#    LONGOPTION_PREFIX の環境変数が設定されていれば、変数名がそれを付けたものとする
#
### 引数
#
#  オプション指定の解析が終わったら、引数を解析する
#  解析できない引数が出た場合は LONGOPTION__OTHER_ARGS に突っ込む
#
### 出力
#
#  シェルで eval できる形に出力する
#  変数名=値 の形
#  LONGOPTION__HELP_TEXT に標準入力の内容が入っている
#  LONGOPTION__OTHER_ARGS にオプションとして解析できなかった値が配列として入っている
#  LONGOPTION__OPTION_ARGS にオプションとして解析できた変数名が配列として入っている（引数指定されたかどうかの判断用）
#
### 使い方例：
# 
# eval "$(cat __EOO__|./scripts/LONGOPTION.sh "$@"
#  --hogehoge HOGE オプション
# LONGOPTION: --hoge HOGE hogehoge のショートオプション的な
#  --opt1 HUGE オプション HUGE
#  --flag-1 フラグ
#  --flag-2 flag(小文字ならオプションとして反応しないのでフラグ扱い)
# __EOO__
# )"
# echo hogehoge=$HOGE
# echo flag-1=$FLAG_1
# echo flag-2=$FLAG_1


set -e
set -o pipefail
#set -u
#set -x

function map_not_init
{
  local name=$1
  eval "declare -p ${name}__keys" >/dev/null 2>&1
  [[ $? != 0 ]]
  return $?
}

function map_init
{
  local name="$1"
  eval "${name}__keys=()"
  eval "${name}__values=()"
}

function map_index
{
  local name=$1
  local key=$2
  local i=0
  if map_not_init "$name" ;then
    return
  fi
  local keys
  eval "keys=(\"\${${name}__keys[@]}\")"
  for ((i=0; i < ${#keys[@]}; i++)) {
    if [[  "${keys[$i]}" = "$key" ]];then
      echo "$i"
      return
    fi
  }
}

function map_put
{
  local name="$1"
  local key="$2"
  local value="$3"
  local i
  if map_not_init "$name"; then
    map_init "$name"
  else
    i=$(map_index "$name" "$key")
  fi
  if [ -z "$i" ];then
    eval "i=\${#${name}__keys[@]}"
    eval ${name}__keys[$i]="\$key"
  fi
  eval ${name}__values[$i]="\$value"
}

function map_get
{
  local name="$1"
  local key="$2"
  local i=$(map_index "$name" "$key")
  if [ ! -z "$i" ];then
    eval echo \"\${${name}__values[$i]}\"
  fi
}

map_init LONGOPTION__OPTIONDIC
map_init LONGOPTION__VALUEDIC
map_init LONGOPTION__NAMEDIC
LONGOPTION_IMPORT=${LONGOPTION_IMPORT:-0}
LONGOPTION_PREFIX=${LONGOPTION_PREFIX:-}
LONGOPTION__HELP_TEXT=""
mode_addhelp=1
mode_parse=1
: parse stdin
while IFS= read line; do
  if [[ "$line" =~ ^LONGOPTION: ]];then
    case "$line" in
    "LONGOPTION:STOP_PARSE")
      mode_parse=0
      ;;
    "LONGOPTION:START_PARSE")
      mode_parse=1
      ;;
    "LONGOPTION:STOP_HELP")
      mode_addhelp=0
      ;;
    "LONGOPTION:START_HELP")
      mode_addhelp=1
      ;;
    *)
      line=${line#LONGOPTION:}
    esac
  else
    if [ $mode_addhelp == 1 ];then
      if [ -z "$LONGOPTION__HELP_TEXT" ];then
        LONGOPTION__HELP_TEXT="$line"
      else
        LONGOPTION__HELP_TEXT="$LONGOPTION__HELP_TEXT
$line"
      fi
    fi
  fi
  if [ $mode_parse == 0 ];then
    continue
  fi
  if [[ "$line" =~ ^\ *--([-a-z0-9]+)\ +([A-Z0-9_]+)(\ |$) ]];then
    optname=${BASH_REMATCH[1]}
    valuename=${LONGOPTION_PREFIX}${BASH_REMATCH[2]}
    map_put LONGOPTION__NAMEDIC "--$optname" "OPTION"
    map_put LONGOPTION__OPTIONDIC "--$optname" "$valuename"
    if [ $LONGOPTION_IMPORT == 0 ];then
      map_put LONGOPTION__VALUEDIC "$valuename" ""
    else
      map_put LONGOPTION__VALUEDIC "$valuename" "${!valuename:-}"
    fi
  elif [[ "$line" =~ ^\ *--(no-)?([-a-z0-9]+) ]];then
    noflag=${BASH_REMATCH[1]}
    optname=${BASH_REMATCH[2]}
    valuename=${BASH_REMATCH[2]}
    valuename=$(echo "$valuename"| tr '[a-z]' '[A-Z]')
    valuename=${valuename//-/_}
    valuename=${LONGOPTION_PREFIX}${valuename}
    map_put LONGOPTION__NAMEDIC "--no-$optname" "NOFLAG"
    map_put LONGOPTION__OPTIONDIC "--no-$optname" "$valuename"
    map_put LONGOPTION__NAMEDIC "--$optname" "FLAG"
    map_put LONGOPTION__OPTIONDIC "--$optname" "$valuename"
    if [ $LONGOPTION_IMPORT != 0 ];then
      if [ "$noflag" == "no-" ];then
        map_put LONGOPTION__VALUEDIC "$valuename" 1
      else
        map_put LONGOPTION__VALUEDIC "$valuename" 0
      fi
    else
      if [ "$noflag" == "no-" ];then
        map_put LONGOPTION__VALUEDIC "$valuename" "${!valuename:-1}"
      else
        map_put LONGOPTION__VALUEDIC "$valuename" "${!valuename:-0}"
      fi
    fi
  fi
done

: parse ARGV
map_init LONGOPTION__OPTION_ARGS
declare -a LONGOPTION__OTHER_ARGS=("")
while (( ${#} > 0 ))
do
  OPTTYPE="$(map_get LONGOPTION__NAMEDIC "${1}")"
  case "$OPTTYPE" in
  FLAG)
    valuename="$(map_get LONGOPTION__OPTIONDIC "${1}")"
    map_put LONGOPTION__VALUEDIC "$valuename" 1
    map_put LONGOPTION__OPTION_ARGS "$valuename" "${1}"
    ;;
  NOFLAG)
    valuename="$(map_get LONGOPTION__OPTIONDIC "${1}")"
    map_put LONGOPTION__VALUEDIC "$valuename" 0
    map_put LONGOPTION__OPTION_ARGS "$valuename" "${1}"
    ;;
  OPTION)
    if (( ${#} > 1 )) ;then
      valuename="$(map_get LONGOPTION__OPTIONDIC "${1}")"
      map_put LONGOPTION__VALUEDIC "$valuename" "${2}"
      map_put LONGOPTION__OPTION_ARGS "$valuename" $(printf "%q %q" "${1}" "${2}")
      shift
    else
      LONGOPTION__OTHER_ARGS=("${LONGOPTION__OTHER_ARGS[@]}" "${1}")
    fi
    ;;
  *)
    LONGOPTION__OTHER_ARGS=("${LONGOPTION__OTHER_ARGS[@]}" "${1}")
  esac
  shift
done

: output options
for ((i=0; i < ${#LONGOPTION__VALUEDIC__keys[@]}; i++)) {
  echo "${LONGOPTION__VALUEDIC__keys[$i]}=$(printf %q "${LONGOPTION__VALUEDIC__values[$i]}")"
}
declare -p LONGOPTION__HELP_TEXT
LONGOPTION__OTHER_ARGS=("${LONGOPTION__OTHER_ARGS[@]:1}")
declare -p LONGOPTION__OTHER_ARGS
if [ ${BASH_VERSINFO[0]} -lt 4 ];then
  :
else
  declare -A LONGOPTION__OPTION_ARGS
  for ((i=0; i < ${#LONGOPTION__VALUEDIC__keys[@]}; i++)) {
    key=LONGOPTION__OPTION_ARGS__keys[$i]
    LONGOPTION__OPTION_ARGS[$key]="${LONGOPTION__OPTION_ARGS__values[$i]}"
  }
  declare -p LONGOPTION__OPTION_ARGS
fi
