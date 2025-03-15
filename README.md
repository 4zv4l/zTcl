# zTcl

Basic TCL implementation in Zig 

## Compile

```
zig build-exe zTcl.zig
```

## Usage

```
./zTcl main.tcl
```

## Example

For this tcl file

```tcl
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

set pu pu
set ts ts
"$pu$ts" "Heyyy $B$A!"

```

It will produce this output

```
test
Hello Simon Blacks !
Defined vars:
- C = 1
- A = 2
- B = 1
Defined vars:
- C = 1
- A = 2
- B = 2
2
Heyyy 22!
```
