#!/bin/bash

export tweusb=/usr/local/TWESDK/Tools/jenprog/tweusb
export com=COM99
export make=/usr/bin/make
export baudrate=115200

MD="$MD TARGET=jn516x"
MD="$MD RF_CHANNEL=25"
MD="$MD BAUD_RATE=UART_RATE_$baudrate"
export MAKEDEFS="$MD"

export CONTIKI=$(dirname "$0")
echo CONTIKI=$CONTIKI

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

sniffer()
{
    python $CONTIKI/../sensniff/sensniff.py -d /dev/tty.usbserial-$tgt -b $baudrate
}
export -f sniffer

router()
{
    sudo $CONTIKI/tools/tunslip6 -v5 -B $baudrate -s /dev/cu.usbserial-$tgt -t /dev/tun0 -v 99 aaaa::1/64
}
export -f router

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

    rm -f ~/.wine/dosdevices/$com
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
    sudo cu -s $baudrate -l /dev/tty.usbserial-$tgt
    rm -f ~/.wine/dosdevices/$com
}
export -f connect

cat <<EOF > /tmp/init-file.tmp
export PS1="jn516x $tgt$ "
EOF
bash --init-file /tmp/init-file.tmp
