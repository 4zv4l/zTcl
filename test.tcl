# simple tcl program
puts [+ 1 2] # print 3
puts {+ 1 2} # print + 1 2 to the screen
puts [+ [+ 1 1] [+ 1 1]]
set name Simon
dumpvar
puts hello
puts $name

proc greet {name} {
    puts $name
}

proc test {name age} {
    puts "Hi $name, you are $age"
}

greet {Jean}
test Simon 21
