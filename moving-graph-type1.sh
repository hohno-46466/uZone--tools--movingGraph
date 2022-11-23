#! /bin/bash

# moving-graph-type1.sh

# ----------------------------------------------------------

# First version: Sun Mar 29 10:53:40 JST 2020
# Prev update: Sun Mar 29 17:12:12 JST 2020
# Last updated: Sun Mar 29 23:58:34 JST 2020

# ----------------------------------------------------------

# References:
# http://bkclass.web.fc2.com/doc_vt100.html
# https://www.mm2d.net/main/prog/c/console-02.html
# http://nanno.dip.jp/softlib/man/rlogin/ctrlcode.html

# ----------------------------------------------------------
# functions
# ----------------------------------------------------------

# カーソルを行頭から数えて第1引数文字目まで移動する

move_posX() {
  echo -n $'\033['; echo -n $1; echo -n 'G'
}

# ----------------------------------------------------------

# カーソルを次行の先頭に移す

move_nextLine_top() {
  echo -n $'\033[1E'
}

# ----------------------------------------------------------

# カーソルを前行の先頭に移す

move_prevLine_top() {
  echo -n $'\033[1F'
}

# ----------------------------------------------------------

# 第1引数で指定した分だけバーを伸ばす

bar_up() {
  for x in $(seq $1); do
    echo -n "#"
  done
  echo -n $'\033[K'
}

# ----------------------------------------------------------

# 第1引数で指定した分だけバーを縮める

bar_down() {
  for x in $(seq $1); do
    echo -n $'\cH'
  done
  echo -n $'\033[K'
}

# ----------------------------------------------------------

# 第1引数で与えた値を制限し，結果を返す

constrain() {

  _v=$1
  [ "x$_v" = "x" ] && _v=0        # _v が "" の場合はゼロにする
  _v=$(echo $_v | sed '/^\..*/s/\./0\./') # _v が .123 形式の場合はゼロにする
  _v=$(echo $_v | sed 's/\..*$//') # 小数点以下を切り捨てる
  # [ "x$_v" = "x" ] && _v=0        
  _min=${2-0}
  _max=${3-100}
  [ "x$_v" = "x" ]  && _v=0
  [ $_v -gt $_max ] && _v=$_max
  [ $_v -lt $_min ] && _v=$_min

  echo $_v
}

# ----------------------------------------------------------

# 棒グラフを描く
# 第1引数：チャネル番号（ゼロ起源）
# 第2引数：表示する値
# 注意：内部で大域変数 curr[] と prev[] を更新している

doit() {
  _ch=$1
  curr[$_ch]=$2

  # 直近の値と現在の値の差 d を求める
  _d=$((${curr[$_ch]} - ${prev[$_ch]}))
  # /bin/echo -n "${curr[$_ch]}-${prev[$_ch]}=$_d,  "  # <-- for debugging

  if [ $_d -lt 0 ]; then
    # _d が負ならバーを縮める
    _x=$((0 - $_d))
    bar_down $_x
  elif [ $_d -gt 0 ]; then
    # _d が正ならバーを伸ばす
    _x=$_d
    bar_up $_x
  else
    # _d がゼロなら何もしない
    :
  fi
  echo -n " (${curr[$_ch]})   "  # <-- おまけ

  # 大域変数 prev[] を更新する
  prev[$_ch]=${curr[$_ch]}
}

# ----------------------------------------------------------

# ----------------------------------------------------------
# スクリプト本体 / Main script
# ----------------------------------------------------------

# 最小値と最大値
minVal=0
maxVal=100

# チャネル数
Nch=6

# 配列の初期値の設定（チャネル数に応じて初期値の数を修正すること）
declare -ai curr=( 0 0 0 0 0 0 )
declare -ai prev=( 0 0 0 0 0 0 )
declare -ai newv=( 0 0 0 0 0 0 )

# 各チャネルのタイトル（説明）を決定
mesgMaxLen=18 # タイトルの長さ
for ch in $(seq 0 1 $(($Nch - 1))); do
  defmesg="Message$ch"
  mesgx[$ch]=${1-"$defmesg"}; shift
done

# 目盛の表示（上側）
echo ""
printf "%-"$mesgMaxLen"s No. "  ""
for x in $(seq 1 10 $(($maxVal - $minVal))); do
  echo -n "---------+"
done
echo ""
# カーソル移動（上側→下側）
for ch in $(seq 1 1 $Nch); do
  move_nextLine_top;
done
# 目盛の表示（下側）
printf "%-"$mesgMaxLen"s No. "  ""
for x in $(seq 1 10 $(($maxVal - $minVal))); do
  echo -n "---------+"
done
# カーソル移動（下側→上側）
for ch in $(seq 1 1 $Nch); do
  move_prevLine_top;
done

# 各チャネルのタイトル（説明）を表示
for ch in $(seq 0 1 $(($Nch - 1))); do
  printf "%-"$mesgMaxLen"s [$ch]"  "${mesgx[$ch]}"
  if [ $ch != $(($Nch - 1)) ]; then
    # カーソルを次の行の先頭に移動
    move_nextLine_top;
  else
    # カーソルを ch0 の先頭に移動
    for ch in $(seq 1 1 $(($Nch - 1))); do
      move_prevLine_top
    done
  fi
done

# この時点でカーソルは ch0 行の先頭にいる

# 各チャネルの値をバーグラフとして表示
while [ 1 ]; do # 無限ループ

  # 標準入力からデータを読み込む
  read line
  vals=($line)

  # 値を調整して newv[] に格納
  for ch in $(seq 0 1 $(($Nch - 1))); do
    newv[$ch]=$(constrain "${vals[$ch]}" $minVal $maxVal)
  done

  # ch0 から順番にバーグラフを描く
  for ch in $(seq 0 1 $(($Nch - 1))); do
    # 現在のチャネルのバーの先頭（根元？, メッセージとCh番号を表示した直後の位置）にカーソルを移す
    # "6" は，[各チャネルのタイトルの末尾とバーの先頭の間の文字数]+1 ( 現状は " [N] ")
    move_posX $(($mesgMaxLen + 6 + ${prev[$ch]}))
    # バーを描く
    doit $ch ${newv[$ch]}
    # カーソルを次のチャネルの先頭に移す
    if [ $ch != $(($Nch -1)) ]; then
      # 最終チャネルでなければカーソルを次の行の先頭に移す
      move_nextLine_top;
    else
      echo ""
      # 最終チャネルならカーソルをch0 の先頭に移す
      for ch in $(seq 1 1 $(($Nch - 0))); do
        move_prevLine_top
      done
    fi
  done

done

# ----------------------------------------------------------
# ----------------------------------------------------------

