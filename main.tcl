proc greet {name family} {
    puts "test"
    puts "Hello $name $family !"
}
set myname Simon
greet $myname Blacks
unset myname

set A 2
set C 1
set B 0
while {!= $A $B} {
    set B [+ $B $C]
    dumpvar
}

if {== $B 2} { puts $B }
if {!= $B 3} { puts "B is not 3" }

set pu pu
set ts ts
"$pu$ts" "Heyyy $B$A!"
