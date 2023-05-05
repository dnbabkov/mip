set ns [new Simulator]

set nf [open out.nam w]

$ns namtrace-all $nf

set f [open out.tr w]

$ns trace-all $f

proc finish {} {
    global tchan_

    global ns f nf
    $ns flush-trace
    close $f
    close $nf

    exec nam out.nam &

    set awkCode {
	{
	    if ($1 == "Q" && NF>2) {
		print $2, $3 >> "temp.q";
		set end $2
	    }
	    else if ($1 == "a" && NF>2)
		print $2, $3 >> "temp.a";
	}
    }

    set f [open temp.queue w]
    puts $f "TitleText: red"
    puts $f "Device: Postscript"
    if { [info exists tchan_] } {
	close $tchan_
    }
    exec rm -f temp.q temp.a
    exec touch temp.a temp.q

    #AWK execution
    exec awk $awkCode all.q
    puts $f \"queue"
    exec cat temp.q >@ $f
    puts $f \n\"ave_queue"
    exec cat temp.a >@ $f
    close $f

    # Запуск xgraph с графиками окна TCP и очереди:
    exec xgraph -bb -tk -x time -t "TCPRenoCWND" WindowVsTimeReno &
    exec xgraph -bb -tk -x time -y queue temp.queue &
    exit 0
    }


Queue/RED set thresh 75
Queue/RED set maxthresh_ 150
Queue/RED set limit 0.1

set N 30

set r(r1) [$ns node]
set r(r2) [$ns node]

$ns simplex-link $r(r1) $r(r2) 20Mb 15ms RED
$ns simplex-link $r(r2) $r(r1) 15Mb 20ms DropTail


for {set i 0} {$i < $N} {incr i} {
    set src($i) [$ns node]
    $ns duplex-link $src($i) $r(r1) 100Mb 20ms DropTail
    set sink($i) [$ns node]
    $ns duplex-link $sink($i) $r(r2) 100Mb 20ms DropTail
    set tcp($i) [$ns create-connection TCP/Reno $src($i) TCPSink $sink($i) $i]
}

for {set i 0} {$i < $N} {incr i} {
    $tcp($i) set window_ 35
    set ftp($i) [$tcp($i) attach-source FTP]
}

# Мониторинг размера окна TCP:
set windowVsTime [open WindowVsTimeReno w]
set qmon [$ns monitor-queue $r(r1) $r(r2) [open qm.out w] 0.1];
[$ns link $r(r1) $r(r2)] queue-sample-timeout;

# Мониторинг очереди:
set redq [[$ns link $r(r1) $r(r2)] queue]
set tchan_ [open all.q w]
$redq trace curq_
$redq trace ave_
$redq attach $tchan_

for {set i 0} {$i < $N} {incr i} {
    $ns at 0.5 "$ftp($i) start"
    $ns at 1.0 "plotWindow $tcp($i) $windowVsTime"

}

$ns at 25.0 "finish"

# Формирование файла с данными о размере окна TCP:
proc plotWindow {tcpSource file} {
    global ns
    set time 0.01
    set now [$ns now]
    set cwnd [$tcpSource set cwnd_]
    puts $file "$now $cwnd"
    $ns at [expr $now+$time] "plotWindow $tcpSource $file"
}

$ns run