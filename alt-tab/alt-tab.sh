#!/usr/bin/env bash
#
# PRIVATE
_lock()             { flock -$1 $3; }
_no_more_locking()  { _lock u $1 $2; _lock xn $1 $2 && rm -f $1; }
_prepare_locking()  { eval "exec $2>\"$1\""; trap "_no_more_locking $1 $2" EXIT; }

# PUBLIC
exlock_now()        { _lock xn $1 $2; }  # obtain an exclusive lock immediately or fail
exlock()            { _lock x $1 $2; }   # obtain an exclusive lock
shlock()            { _lock s $1 $2; }   # obtain a shared lock
unlock()            { _lock u $1 $2; }   # drop a lock

input_script=$1
reply_script=$2
if [ -z "$input_script" ]; then
    echo "Must supply an input script (generates options)"
fi
if [ -z "$reply_script" ]; then
    echo "Must supply a reply script (processes the selection)"
fi

var=/tmp/alt-tab
if [ "$ALT_TAB_MUTEX" = "" ]; then
    var=$ALT_TAB_MUTEX
fi
mkdir -p $var

# ON START
_prepare_locking $var/main-lock 99
_prepare_locking $var/advance-lock 98

if exlock_now $var/main-lock 99; then

    $input_script > $var/listing

    exlock $var/advance-lock 98

    touch $var/advance

    contents=$(cat $var/advance)
    if [ -z $contents ]; then
        count=1
    else
        count=$((contents))
    fi

    width=1600

    dims=$(xrandr | grep '*' | head -n1 | awk '{print $1}')
    xdim=$(echo $dims | awk -Fx '{print $1}')
    ydim=$(echo $dims | awk -Fx '{print $2}')

    selection=$(cat $var/listing | sed 's/\t/    /g' | \
        dmenu -w $width -l 8 -fn 8 -x $((xdim/2 - width/2)) -y $((ydim/2 - 300)) -alttab $count)

    $reply_script "$selection"

    cp $var/advance $var/old-advance
    rm $var/advance
    unlock $var/advance-lock 98
    unlock $var/main-lock 99
else
    exlock $var/advance-lock 98

    touch $var/advance
    contents=$(cat $var/advance)
    if [ -z $contents ]; then
        contents=1
    fi
    count=$((contents + 1))
    echo $count > $var/advance

    unlock $var/advance-lock 98
fi
