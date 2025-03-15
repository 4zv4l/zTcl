puts 1 # heyy
puts {+ 1 2}
puts [+ 2 2]
puts [+ [+ 2 2] [+ 1 1]]

proc greet {name} {
    puts "FIRST LINE"
    puts "SECOND LINE"
}

# cause a recursive panic
greet

set name Simon

# cause a recursive panic
dumpvar
