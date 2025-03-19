# basic var and proc
proc greet {name family} {
    puts "test"
    puts "Hello $name $family !"
}
set myname Simon
greet $myname Blacks
unset myname

# looping
set A 2
set C 1
set B 0
while {!= $A $B} {
    set B [+ $B $C]
    dumpvar
}

# branching
if {== $B 2} { puts $B }
if {!= $B 3} { puts "B is not 3" }

# interpolation magic
set pu pu
set ts ts
"$pu$ts" "Heyyy $B$A!"

# implement for loop
proc for {init val cond end block} {
    set $init $val
    while {$cond} {
        $block
        $end
    }
    unset $init
}

set n ""
for i 0 {!= $i 5} {set i [+ 1 $i]} {
    set n "$n$i"
}
puts "=> $n"

# I/O
print "your name: "
set name [gets]
puts "Hi $name !"

# print/copy file content
print "path to file to print: "; set filepath [gets]
set filedata [gets $filepath]; print $filedata
print "path to copy file content: "; set copyfilepath [gets]
puts $copyfilepath $filedata
