longoption
==========

[![Build Status](https://travis-ci.org/team-lab/longoption.svg?branch=master)](https://travis-ci.org/team-lab/longoption)

[English](README.md)

bash の 引数解析器です. 以下の問題を解決します

 * bash で引数を扱うと、コードの半分以上が引数の解析に費やされる
 * コードとヘルプテキストの両方をメンテしなくてはならず乖離しがち

## Example
 
```bash
# ヘルプテキストを記述します. bash では変数に複数行文字列を入力するのに特殊なリテラルは必要ありません
HELP="
  --opt1 OPTION1   Option1 は引数一つの引数を持ちます ( 指定されないと '' )
  --opt2 OPTION2   Option2 は引数一つの引数を持ちます ( 指定されないと '' )
  --flag           引数を指定しないとフラグ扱いです ( 引数に指定されると 1, 指定されないと 0 )
  --no-revflag     ’no-' で始まると反転フラグ扱いです ( 引数に指定されると 0, 指定されないと 1 )
  --help           'HELP=1'になるフラグです
"

# ヘルプテキストと引数を longpotion.sh に渡し、その出力を eval します
eval "$(longoption.sh "$HELP" "$@")"

# すると、ヘルプテキストに対応した環境変数が使えるようになります
echo opt1=$OPTION1
echo opt2=$OPTION2
echo flag=$FLAG
echo revflag=$REVFLAG

if [ -z "HOGE" ];then
  echo "$LONGOPTION__HELP_TEXT" # HELP TEXT
  exit
fi

# ヘルプテキストで書かれていなかった引数の利用
if [ ${#LONGOPTION__OTHER_ARGS[@]} != 0 ];then
  echo "未知のオプション: ${LONGOPTION__OTHER_ARGS[@]}"
  echo "$LONGOPTION__HELP_TEXT"
  exit -1
fi
```

 * 引数設定をヘルプテキスト（第一引数）から解析します
 * 'bash script' を出力します. 出力を `eval` することで環境変数として引数を環境変数から利用できます
 * ヘルプテキストで指定されなかった引数を別の変数として利用できます

### どのように動くか

longoption は自らの第一引数の内容を解析して、それに基づき、後続の引数を解析し、環境変数に設定するための bash スクリプトを標準出力に出力します. longoption を単体で使うと

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
```

このような出力を得ることができます。


### ヘルプテキストはどのように解析されるか

longoption は最初の引数をヘルプテキストとして解析します. `--optname VALNAME` というスタイルにのみ対応しています.
longoption は `^\ *--([a-z][-a-z0-9]*)\ +([A-Z][A-Z0-9_]*)(\ |$)` をヘルプテキストの各行から探します
もし見つかったら,

  * `--option-name VALUENAME` の形式なら、値付きの引数と認識します. この形式の引数が見つかると、環境変数 `VALUENAME` に値を設定します（引数が見つからなければ空文字を設定します）
  * `--option-name` の形式なら、値なしの引数（フラグ）と認識します. この形式の引数が見つかると `OPTION_NAME` に `1` を設定します(引数が見つからなければ `0` を設定します). 環境変数はオプションに対して `tr [-a-z] [_A_Z]` の変換がされます（小文字は大文字に、 `-` は `_` に）
  * `--no-option-name` の形式なら、反転フラグと認識します. 通常のフラグと違って、デフォルトが `1` になります

  * 注意：例えば `--option-name Document` はフラグです. 変数名として `[A-Z][A-Z0-9_]*` （英数大文字とアンダーバー）しか指定できないからです


### 解析オプション

ヘルプテキストに `LONGOPTION:` で始まる行があると、 longoption は解析モードを変更します.

  * `LONGOPTION:` は、"この行はヘルプテキストに含まない"と認識します。ただし、引数設定としては解析されます。ヘルプテキストに表示したくない引数設定などを記述します。
  * `LONGOPTION:STOP_PARSE` が見つかると、その行以降は、引数設定の解析を中断します.( ただし、ヘルプテキストの記述としては中断されません ) 引数設定としてご認識されそうな文章をヘルプテキストに追加する時に利用します。
  * `LONGOPTION:START_PARSE` が見つかると、中断していた引数設定の解析を再開します。
  * `LONGOPTION:STOP_HELP` が見つかると、その行以降は、ヘルプテキストとして追加しません.( ただし、引数設定の解析は中断されません ) 隠しオプション的なものを大量に追加する時に利用します。
  * `LONGOPTION:START_HELP` が見つかると、中断していたヘルプテキストへの追加を再開します。

#### example

```bash
eval "$(longoption.sh \
'この行は引数設定として動作します. またこの行は `LONGOPTION__HELP_TEXT` に追加されます.
  --opt1 OPTION1 : この行は引数設定として動作します. またこの行は `LONGOPTION__HELP_TEXT` に追加されます.
LONGOPTION: --opt2 OPTION2 : この行は引数設定として動作します. この行は `LONGOPTION__HELP_TEXT` に追加されません.
LONGOPTION:STOP_PARSE
  --opt3 OPTION3 : この行は引数設定として動作しません. しかし `LONGOPTION__HELP_TEXT` には追加されます.
LONGOPTION:START_PARSE
LONGOPTION:STOP_HELP
  --opt4 OPTION4 : この行は引数設定として動作します. しかし `LONGOPTION__HELP_TEXT` に追加されません.
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
この行は引数設定として動作します. またこの行は `LONGOPTION__HELP_TEXT` に追加されます.
  --opt1 OPTION1 : この行は引数設定として動作します. またこの行は `LONGOPTION__HELP_TEXT` に追加されます.
  --opt3 OPTION3 : この行は引数設定として動作しません. しかし `LONGOPTION__HELP_TEXT` には追加されます.
OPTION1=O1
OPTION2=O2
OPTION3=
OPTION4=O4
--opt3 O3
```

### 動作オプション (環境変数で指定します)

環境変数 'LONGOPTION' を設定することで、 longoption の動作を変更することができます。

  * `--import` が設定されていれば、デフォルト値を環境変数から取り込みます.
  * `--prefix PREFIX` が設定されていれば, 最終的に設定される環境変数に接頭辞が付きます.
  * `--stop STOPWORD` が設定されていれば, オプション解析を中断するマークを設定できます.

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

#### example 2. prefix

```bash
DOC="--v1 V1"
ARGS="--v1 V1"

echo "---- no set prefix"
eval "$(longoption.sh "$DOC" $ARGS)"
echo V1=$V1
echo HOGE_V1=$HOGE_V1

V1=
HOGE_V1=

echo "---- set prefix HOGE_"
eval "$(LONGOPTION='--prefix HOGE_' longoption.sh "$DOC" $ARGS)"
echo V1=$V1
echo HOGE_V1=$HOGE_V1
```

↓

```
---- no set prefix
V1=V1
HOGE_V1=
---- set prefix HOGE_
V1=
HOGE_V1=V1
```

#### example 3. stop

`LONGOPTION_STOP` is set option end

```bash
DOC="
--v1 V1
--v2 V2"
ARGS="--v1 V1 -- --v2 V2"

echo "---- no set stop"
eval "$(longoption.sh "$DOC" $ARGS)"
echo V1=$V1
echo V2=$V2

V1=
V2=

echo "---- set stop"
eval "$(LONGOPTION='--stop --' longoption.sh "$DOC" $ARGS)"
echo V1=$V1
echo V2=$V2
```

↓

```
---- no set stop
V1=V1
V2=V2
---- set stop
V1=V1
V2=
```


### Outputs

longoption.sh output bash shell script. you can use it by `eval`.
output variables is

 * `LONGOPTION__HELP_TEXT` is help document
 * `LONGOPTION__OTHER_ARGS` is no option arguments (array).
 * `LONGOPTION__OPTION_ARGS` is assoc-map. like `(["VALUENAME"] = "--option value1")`. (bash v4 only)


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
