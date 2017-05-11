#!/bin/bash

set -e
set -o pipefail
#set -u
#set -x

function map_index
{
  local name=${1}[@]
  local key=$2
  local i=0
  local keys=("${!name}")
  for ((i=0; i < ${#keys[@]}; i+=2)) {
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
  local i=$(map_index "$name" "$key")
  if [ -z "$i" ];then
    eval "i=\${#${name}[@]}"
    eval ${name}[$i]="\$key"
  fi
  eval ${name}[$((i+1))]="\$value"
}

function map_get
{
  local name="$1"
  local key="$2"
  local i=$(map_index "$name" "$key")
  if [ ! -z "$i" ];then
    eval echo \"\${${name}[$((i+1))]}\"
  fi
}

if [ "$LONGOPTION" == "--prefix LONGOPTION_" ];then
  LONGOPTION_PREFIX=LONGOPTION_
  LONGOPTION_STOP=
  LONGOPTION_IMPORT=0
  LONGOPTION_HELP_EXIT_FLAG=
  LONGOPTION_HELP_EXIT_CODE=0
else
  eval "$(LONGOPTION='--prefix LONGOPTION_' $0 '
    --import
    --prefix PREFIX
    --stop STOP
    --help-exit-flag HELP_EXIT_FLAG
    --help-exit-code HELP_EXIT_CODE
  ' $LONGOPTION)"
fi
LONGOPTION__OPTIONDIC=()
LONGOPTION__VALUEDIC=()
LONGOPTION__NAMEDIC=()
LONGOPTION__HELP_TEXT=""
mode_addhelp=1
mode_parse=1
: parse $1
DOC=$1
shift
exec <<<"$DOC"
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
  if [[ "$line" =~ ^\ *--([a-z][-a-z0-9]+)\ +([A-Z][A-Z0-9_]*)(\ |$) ]];then
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
OPTION_ARGS=()
declare -a LONGOPTION__OTHER_ARGS=()
while (( ${#} > 0 ))
do
  if [ "${1}" == "${LONGOPTION_STOP}" ];then
    shift
    LONGOPTION__OTHER_ARGS=("${LONGOPTION__OTHER_ARGS[@]}" "${@}")
    break
  fi
  OPTTYPE="$(map_get LONGOPTION__NAMEDIC "${1}")"
  case "$OPTTYPE" in
  FLAG)
    valuename="$(map_get LONGOPTION__OPTIONDIC "${1}")"
    map_put LONGOPTION__VALUEDIC "$valuename" 1
    map_put OPTION_ARGS "$valuename" "${1}"
    ;;
  NOFLAG)
    valuename="$(map_get LONGOPTION__OPTIONDIC "${1}")"
    map_put LONGOPTION__VALUEDIC "$valuename" 0
    map_put OPTION_ARGS "$valuename" "${1}"
    ;;
  OPTION)
    if (( ${#} > 1 )) ;then
      valuename="$(map_get LONGOPTION__OPTIONDIC "${1}")"
      map_put LONGOPTION__VALUEDIC "$valuename" "${2}"
      map_put OPTION_ARGS "$valuename" "$(printf "%q %q" "${1}" "${2}")"
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
if [ -n "$LONGOPTION_HELP_EXIT_FLAG" -a "$(map_get LONGOPTION__VALUEDIC "$LONGOPTION_HELP_EXIT_FLAG")" == "1" ];then
  printf "
echo %q
exit %d" "$LONGOPTION__HELP_TEXT" "$LONGOPTION_HELP_EXIT_CODE"
  exit
fi
for ((i=0; i < ${#LONGOPTION__VALUEDIC[@]}; i+=2)) {
  echo "${LONGOPTION__VALUEDIC[$i]}=$(printf %q "${LONGOPTION__VALUEDIC[$((i+1))]}")"
}
declare -p LONGOPTION__HELP_TEXT
declare -p LONGOPTION__OTHER_ARGS
if [ ${BASH_VERSINFO[0]} -lt 4 ];then
  :
else
  declare -A LONGOPTION__OPTION_ARGS=()
  for ((i=0; i < ${#OPTION_ARGS[@]}; i+=2)) {
    key="${OPTION_ARGS[$i]}"
    LONGOPTION__OPTION_ARGS[$key]="${OPTION_ARGS[$((i+1))]}"
  }
  declare -p LONGOPTION__OPTION_ARGS
fi

