#!/bin/bash

tgt_cc2650=false
tgt_jn516x=false

if [ .$1 == .cc2650 ]; then
    tgt_type="CC2650"
    tgt_cc2650=true
elif [ .$1 == .jn516x ]; then
    tgt_type="JN516x"
    tgt_jn516x=true
else
    tgt_type="JN516x"
    tgt_jn516x=true
fi
echo target type is $tgt_type

export tweusb=/usr/local/TWESDK/Tools/jenprog/tweusb
export com=COM99
export make=/usr/bin/make
export baudrate=115200

if $tgt_jn516x; then
MD="$MD TARGET=jn516x"
MD="$MD RF_CHANNEL=25"
MD="$MD BAUD_RATE=UART_RATE_$baudrate"
fi
if $tgt_cc2650; then
MD="$MD TARGET=srf06-cc26xx"
MD="$MD BOARD=launchpad/cc2650"
fi

export MAKEDEFS="$MD"

export CONTIKI=`cd $(dirname "$0") && pwd`
echo CONTIKI=$CONTIKI

if $tgt_jn516x; then
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

load
serial_port=/dev/cu.usbserial-$tgt
fi
if $tgt_cc2650; then
tgt=`ls /dev/cu.usbmodemL* | head -1 | sed 's|/dev/cu.usbmodem||'`
serial_port=/dev/cu.usbmodem$tgt
fi

echo target: $tgt
echo serial port: $serial_port
export serial_port
export tgt

sniffer()
{
    echo python $CONTIKI/../sensniff/sensniff.py -d $serial_port -b $baudrate
    python $CONTIKI/../sensniff/sensniff.py -d $serial_port -b $baudrate
}
export -f sniffer

router()
{
    echo sudo $CONTIKI/tools/tunslip6 -v5 -B $baudrate -s $serial_port -t /dev/tun0 -v 99 aaaa::1/64
    sudo $CONTIKI/tools/tunslip6 -v5 -B $baudrate -s $serial_port -t /dev/tun0 -v 99 aaaa::1/64
}
export -f router

make()
{
    echo $make $MAKEDEFS $*
    $make $MAKEDEFS $*
}
export -f make

if $tgt_jn516x; then
flash() {
    unload
    echo set $tgt into program mode...
    $tweusb -p $tgt
    echo
    load

    rm -f ~/.wine/dosdevices/$com
    ln -s $serial_port ~/.wine/dosdevices/$com
    wine ~/.wine/drive_c/NXP/bstudio_nxp/sdk/JN-SW-4163/../../../ProductionFlashProgrammer/JN51xxProgrammer.exe -V 10 -v -s $com -I 38400 -P 115200 -Y -f *.jn516x.bin
}
export -f flash
fi
if $tgt_cc2650; then
flash() {
    #openocd -f interface/cmsis-dap.cfg -c "transport select jtag" -f target/cc26xx.cfg -c init
    cmdfile=/tmp/jlinkcmd.tmp
    cat <<EOF > $cmdfile
        device CC2650F128
        si jtag
        speed auto
        connect
EOF
    echo loadfile *.hex >> $cmdfile
    echo exit >> $cmdfile
    JLinkExe -device CC2650F128 -if JTAG -jtagconf -1,-1 -CommanderScript $cmdfile
}
export -f flash
fi

if $tgt_jn516x; then
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
    sudo cu -s $baudrate -l $serial_port
    rm -f ~/.wine/dosdevices/$com
}
export -f connect
fi

cat <<EOF > /tmp/init-file.tmp
export PS1="$tgt_type $tgt$ "
EOF
bash --init-file /tmp/init-file.tmp
