longoption
==========

arguments parser for bash. only style `--optname VALNAME`.

## Example
 
```bash
HELP="
  --hogehoge HOGE Option1
  --opt1 HUGE   Option HUGE
  --verbose     Verbose Option ( default 0 )
  --no-lineend  This is Flag 2 ( default 1 )
"

eval "$(echo "$HELP"|longoption.sh "$@")"
echo hogehoge=$HOGE
echo verbose=$VERBOSE  # 1 or 0
echo lineend=$LINEEND  # 1 or 0

if [ -z "HOGE" ];then
  echo "$LONGOPTION__HELP_TEXT" # HELP TEXT
  exit
fi

if [ ${#LONGOPTION__OTHER_ARGS[@]} != 0 ];then
  echo "Unknown options ${LONGOPTION__OTHER_ARGS[@]}"
  echo "$LONGOPTION__HELP_TEXT"
  exit -1
fi
```

 * Get option settings from help document (from stdin).
 * Output 'bash script'. you can `eval` this and get options as environment variables.
 * Can get un parsed options.

### how to parse

longoption read document from stdin.
longoption search `^\ *--([a-z][-a-z0-9]*)\ +([A-Z][A-Z0-9_]*)(\ |$)` for each lines.
if finds,

  * `--option-name VALUENAME` is long option has value. set for environment variable names `VALUENAME` to argument .
  * `--option-name` is flag option. has not value. set for environment variable names `OPTION_NAME` to `1` (default value is `0`).
  * `--no-option-name` is disable flag option. has not value. set for environment variable names `OPTION_NAME` to `0` (default value is `1`).

  * `--option-name Document` is flag option. variable-name format is `[A-Z][A-Z0-9_]*`.

### parse option (in document)

`LONGOPTION:` is keyword. if find this, longoption change parse mode.

  * `LONGOPTION:` is 'skip this line'. this line don't add to help document. but option setting is effective.
  * `LONGOPTION:STOP_PARSE` is stop option parse.( but help document adding dosen't stop )
  * `LONGOPTION:START_PARSE` is resule option parse.
  * `LONGOPTION:STOP_HELP` is stop help document adding.(but option parse dosen't stop )
  * `LONGOPTION:START_HELP` is resume help document adding.

#### example

```bash
eval "$(cat <<"__EOO__"|longoption.sh --opt1 O1 --opt2 O2 --opt3 O3 --opt4 O4
this line is added to `LONGOPTION__HELP_TEXT`
  --opt1 OPTION1 : effective this . and this line is added to `LONGOPTION__HELP_TEXT` .
LONGOPTION: --opt2 OPTION2 : effective this. this line is not added to `LONGOPTION__HELP_TEXT` .
LONGOPTION:STOP_PARSE
  --opt3 OPTION3 : no effective this. but this line is added to `LONGOPTION__HELP_TEXT` .
LONGOPTION:START_PARSE
LONGOPTION:STOP_HELP
  --opt4 OPTION4 : effective this. but this line is not added to `LONGOPTION__HELP_TEXT` .
LONGOPTION:START_HELP
__EOO__
)"

echo "$LONGOPTION__HELP_TEXT"
echo OPTION1=$OPTION1 # maybe "O1"
echo OPTION2=$OPTION2 # maybe "O2"
echo OPTION3=$OPTION3 # maybe ""
echo OPTION4=$OPTION4 # maybe "O4"
echo "${LONGOPTION__OTHER_ARGS[@]}"
```

is

```
this line is added to `LONGOPTION_HELP_TEXT`
  --opt1 OPTION1 : effective this . and this line is added to `LONGOPTION_HELP_TEXT` .
  --opt3 OPTION3 : no effective this. but this line is added to `LONGOPTION_HELP_TEXT` .
OPTION1=O1
OPTION2=O2
OPTION3=
OPTION4=O4
--opt2 O2 --opt4 O4
```

### parse option (from environment variables)

  * if `LONGOPTION_IMPORT` is `1`, import option value from environment.
  * if `LONGOPTION_PREFIX` dose set, export value has prefix.

#### example

if you can't use `LONGOPTION_IMPORT`, no exists arguments is set brank.

```bash
export V1=exists
eval "$(echo "--v1 V1"|longoption.sh)"
echo V1=$V1
```

is

```
V1=
```

if you set use `LONGOPTION_IMPORT=1`, set from environment variables.

```bash
export V1=exists
eval "$(echo "--v1 V1"|LONGOPTION_IMPORT=1 longoption.sh)"
echo V1=$V1
```

is

```
V1=1
```

`LONGOPTION_PREFIX` is prefix.

```bash
eval "$(echo "--v1 V1"|LONGOPTION_PREFIX=HOGE_ longoption.sh --v1 V1)"
echo V1=$HOGE_V1
```

is

```
V1=V1
```

### Outputs

longoption.sh output bash shell script. you can use it by `eval`.
output variables is

 * `LONGOPTION__HELP_TEXT` is help document
 * `LONGOPTION__OTHER_ARGS` is no option arguments (array).
 * `LONGOPTION__OPTION_ARGS` is assoc-map. like `("--opt" = "OPT1")`. (bash v4 only)


Platform Support with Tested System
-----------------------------------

 * [x] GNU bash, version 3.2.25
 * [x] GNU bash, version 3.2.57 ( mac os X )
 * [x] GNU bash, version 4.2.46
