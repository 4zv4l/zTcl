proc for {init val cond end block} {
    set $init $val
    while {$cond} {
        $block
        $end
    }
}

for i 0 {!= $i 5} {set i [+ 1 $i]} {
    puts "$i"
}
