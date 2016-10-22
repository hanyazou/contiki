#!/bin/bash

export tweusb=/usr/local/TWESDK/Tools/jenprog/tweusb
export com=COM99
export make=/usr/bin/make

MD="$MD TARGET=jn516x"
MD="$MD RF_CHANNEL=25"
MD="$MD BAUD_RATE=UART_RATE_230400"
export MAKEDEFS="$MD"

devices()
{
    $tweusb -l 2>&1 | awk '
        BEGIN{ FS=","}
        /^#.*/{ next }
        {print $2}'
}

unload()
{
    sudo kextunload -bundle com.FTDI.driver.FTDIUSBSerialDriver > /dev/null 2>&1
    sudo kextunload -bundle com.apple.driver.AppleUSBFTDI > /dev/null 2>&1
}
export -f unload

load()
{
    sudo kextload -bundle com.FTDI.driver.FTDIUSBSerialDriver
}
export -f load

unload
$tweusb -l
tgts=(`devices`)
if [ ${tgts[1]}x == x ]; then
    tgt=${tgts[0]}
else
    echo
    echo 'Multiple targets found.'
    PS3='Please select: '
    select tgt in "${tgts[@]}"; do
       break
    done
fi

echo target=$tgt
export tgt
load

make()
{
    #echo $make TARGET=jn516x RF_CHANNEL=25 BAUD_RATE=UART_RATE_230400 $*
    #$make TARGET=jn516x RF_CHANNEL=25 BAUD_RATE=UART_RATE_230400 $*
    echo $make $MAKEDEFS $*
    $make $MAKEDEFS $*
}
export -f make

flash() {
    unload
    echo set $tgt into program mode...
    $tweusb -p $tgt
    echo
    load

    ln -s /dev/tty.usbserial-$tgt ~/.wine/dosdevices/$com
    wine ~/.wine/drive_c/NXP/bstudio_nxp/sdk/JN-SW-4163/../../../ProductionFlashProgrammer/JN51xxProgrammer.exe -V 10 -v -s $com -I 38400 -P 115200 -Y -f *.jn516x.bin
}
export -f flash

reset() {
    unload
    echo set $tgt into program mode...
    $tweusb -r $tgt
    echo
    load
}
export -f reset

connect()
{
    echo "connect to /dev/tty.usbserial-$tgt. (type '~.' and return to disconnect.)"
    sudo cu -s 230400 -l /dev/tty.usbserial-$tgt
    rm -f ~/.wine/dosdevices/$com
}
export -f connect

cat <<EOF > /tmp/init-file.tmp
export PS1="jn516x $tgt$ "
EOF
bash --init-file /tmp/init-file.tmp
