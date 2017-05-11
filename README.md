longoption
==========

[![Build Status](https://travis-ci.org/team-lab/longoption.svg?branch=master)](https://travis-ci.org/team-lab/longoption)

It is an argument analyzer of bash. It solves the following problem

 * Handling arguments with bash, more than half of the code is spent analyzing arguments
 * I have to maintain both the code and the help text and it tends to diverge

[Japanese README is here](README.ja.md)

## Example
 
```bash
# set help document. Bash does not require special literals to enter multi-line strings in variables
HELP="
  --opt1 OPTION1   Option1 has one argument ( default "" )
  --opt2 OPTION2   Option2 has one argument ( default "" )
  --flag           flag has no arguments ( if setted, it is 1, default 0 )
  --no-revflag     revflag has no arguments ( if setted, it is 0, default 1 )
"

# Pass help text and arguments to longpotion.sh and eval the output
eval "$(longoption.sh "$HELP" "$@")"

# you can get option values
echo opt1=$OPTION1
echo opt2=$OPTION2
echo flag=$FLAG
echo revflag=$REVFLAG
```

 * Parse the argument setting from the help text (first argument)
 * longoption output 'Bash script', you can use the argument as an environment variable from 'environment variable' by `eval` the output

### how it work

Longoption parses the contents of its first argument, analyzes the following arguments based on it, and outputs a bash script to standard output to set it as an environment variable.
If you use longoption alone

```bash
./longoption.sh "Option:
  --option1 VALUE_NAME1" --option1 V1
```

↓

```
VALUE_NAME1=V1
declare -- LONGOPTION__HELP_TEXT="Option:
--option1 VALUE_NAME1"
declare -a LONGOPTION__OTHER_ARGS='()'
declare -A LONGOPTION__OPTION_ARGS='([VALUE_NAME1]="--option1 V1" )' # only bash 4
```

You can get such output. It is supposed to do this using `eval`. Arguments The following variables are output in addition to the specified values.

  * Help text is assigned to `LONGOPTION__HELP_TEXT`.
  * Arguments other than those specified in the help text (missing from analysis) are assigned as an array to `LONGOPTION__OTHER_ARGS`.
  * An associative array of the form `(["VALUENAME"] ="--option value 1")` is assigned to `LONGOPTION__OPTION_ARGS` (bash v4 only)

### how it parse your help text

Longoption read help text from first argument.
Longoption search `^\ *--([a-z][-a-z0-9]*)\ +([A-Z][A-Z0-9_]*)(\ |$)` for each lines.
if finds,

  * `--option-name VALUENAME` is long option has value. set for environment variable names `VALUENAME` to argument .
  * `--option-name` is flag option. has not value. set for environment variable names `OPTION_NAME` to `1` (default value is `0`). option to variable name converter is `tr [-a-z] [_A_Z]`.
  * `--no-option-name` is reverse flag option. has not value. set for environment variable names `OPTION_NAME` to `0` (default value is `1`).

  * `--option-name Document` is flag option. variable-name format is `[A-Z][A-Z0-9_]*`.

### parse option (in help text)

`LONGOPTION:` is keyword. if find this, longoption change parse mode.

  * `LONGOPTION:` is 'skip this line'. this line don't add to help text. but option setting is effective.
  * `LONGOPTION:STOP_PARSE` is stop option parse.( but help text adding dosen't stop )
  * `LONGOPTION:START_PARSE` is resule option parse.
  * `LONGOPTION:STOP_HELP` is stop help text adding.(but option parse dosen't stop )
  * `LONGOPTION:START_HELP` is resume help text adding.

#### example

```bash
eval "$(longoption.sh 'this line is added to `LONGOPTION__HELP_TEXT`
  --opt1 OPTION1 : effective this . and this line is added to `LONGOPTION__HELP_TEXT` .
LONGOPTION: --opt2 OPTION2 : effective this. this line is not added to `LONGOPTION__HELP_TEXT` .
LONGOPTION:STOP_PARSE
  --opt3 OPTION3 : no effective this. but this line is added to `LONGOPTION__HELP_TEXT` .
LONGOPTION:START_PARSE
LONGOPTION:STOP_HELP
  --opt4 OPTION4 : effective this. but this line is not added to `LONGOPTION__HELP_TEXT` .
LONGOPTION:START_HELP' \
  --opt1 O1 --opt2 O2 --opt3 O3 --opt4 O4)"

echo "$LONGOPTION__HELP_TEXT"
echo OPTION1=$OPTION1 # maybe "O1"
echo OPTION2=$OPTION2 # maybe "O2"
echo OPTION3=$OPTION3 # maybe ""
echo OPTION4=$OPTION4 # maybe "O4"
echo "${LONGOPTION__OTHER_ARGS[@]}"
```

↓

```
this line is added to `LONGOPTION__HELP_TEXT`
  --opt1 OPTION1 : effective this . and this line is added to `LONGOPTION__HELP_TEXT` .
  --opt3 OPTION3 : no effective this. but this line is added to `LONGOPTION__HELP_TEXT` .
OPTION1=O1
OPTION2=O2
OPTION3=
OPTION4=O4
--opt3 O3
```

### parse option (from environment variables)

Parse option set from environment names 'LONGOPTION'.

  * If `--import` is set, import option value from environment.
  * If `--prefix PREFIX` is set, export value has prefix.
  * If `--stop STOPWORD` is set, stop option parsing after it.
  * If `--help-flag` is set, If the flag is set, you can display the help text and exit the program.
    * `--help-exit HELP_EXIT` allows you to set the exit code at the end of the help display, default is `0`
  * If `--unknown-option-exit-code UNKNOWN_OPTION_EXIT_CODE` is set, if an item not defined in the help text is specified as an argument, the program is terminated. For example, specify `-1`.
     * You can change the message at the end by specifying `--unknown-option-exit-message UNKNOWN_OPTION_EXIT_MESSAGE`. The default is 'Unknonw options:'.


#### example 1. import

if you can't use `LONGOPTION`, no exists arguments is set brank.

```bash
export V1=exists
eval "$(longoption.sh "--v1 V1")"
echo V1=$V1
```

↓

```
V1=
```

if you set use `LONGOPTION='--imoprt'`, set from environment variables.

```bash
export V1=exists
eval "$(LONGOPTION='--import' longoption.sh "--v1 V1")"
echo V1=$V1
```

↓

```
V1=exists
```

`LONGOPTION='--prefix PREFIX'` is prefix.

```bash
eval "$(LONGOPTION='--prefix HOGE_' longoption.sh "--v1 V1" --v1 V1)"
echo V1=$HOGE_V1
```

↓

```
V1=V1
```

#### example 2. stop

`LONGOPTION_STOP` is set option end

```bash
eval "$(LONGOPTION='--stop --' longoption.sh "
--v1 V1
--v2 V2
" --v1 V1 -- --v2 V2)"
echo V1=$V1
echo V2=$V2
```

↓

```
V1=V1
V2=
```

If you want to make more complicated control, you can do the same operation with the following code.

```bash
DOC="--help   show this text"

eval "$(longoption.sh "$DOC" --bad-option)"
if [ ${#LONGOPTION__OTHER_ARGS[@]} -ne 0 ];then
  echo "$LONGOPTION__HELP_TEXT"
  echo "Unknown options: ${LONGOPTION__OTHER_ARGS[@]}"
  exit
fi
```


#### example 3. help

if set `LONGOPTION='--help-exit-flag HELP'` , and `--help` exits in arguments, then longoption outputs bash scripts that show help text and exit.

```bash
DOC="--help   show this text"

echo "** brefore parse"
eval "$(LONGOPTION='--help-exit-flag HELP' longoption.sh "$DOC" --help)"
echo "** after parse"
```

↓

```
** brefore parse
--help   show this text
```

If you change exit code, you can use `--help-exit-code` like `LONGOPTION='--help-exit-flag HELP --help-exit-code -1'` .

#### example 4. unknown option exit


If `LONGOPTION='--unknown-option-exit-code -1'` is set, if an item not defined in the help text is specified as an argument, the program ends with exit code -1 . By specifying `--unknown-option-exit-message`, you can change the message at the end.

```bash
DOC="--help   show this text"

echo "** brefore parse"
eval "$(LONGOPTION="--unknown-option-exit-code 0 --unknown-option-exit-message 'this is unknown:'" longoption.sh "$DOC" --bad-option)"
echo "** after parse"
```

↓

```
** brefore parse
--help   show this text

this is unknown: --bad-option
```

If you want to make more complicated control, you can do the same operation with the following code.

```bash
DOC="--help   show this text"

eval "$(longoption.sh "$DOC" --bad-option)"
if [ ${#LONGOPTION__OTHER_ARGS[@]} -ne 0 ];then
  echo "$LONGOPTION__HELP_TEXT"
  echo "Unknown options: ${LONGOPTION__OTHER_ARGS[@]}"
  exit
fi
```


Platform Support with Tested System
-----------------------------------

 * [x] GNU bash, version 3.2.25
 * [x] GNU bash, version 3.2.57 ( mac os X )
 * [x] GNU bash, version 4.2.25 ( travis-ci )
 * [x] GNU bash, version 4.2.46
 * [x] GNU bash, version 4.3.42(5)-release (x86_64-pc-msys)

Licence
-------

[MIT License](LICENCE.txt)
