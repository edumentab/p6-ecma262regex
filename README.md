### ECMA262Regex ![Build Status](https://github.com/edumentab/p6-ecma262regex/actions/workflows/ci.yml/badge.svg)

This module parses ECMA262 regex syntax and can also translate it to a Raku
regex.

### SYNOPSIS

```
use v6;
use ECMA262Regex;

say ECMA262Regex.validate('\e'); # False;
say ECMA262Regex.validate('^fo+\n'); # True

# Translate regex into a Raku one (string form)
say ECMA262Regex.as-perl6('^fo+\n'); # '^fo+\n'
say ECMA262Regex.as-perl6('[^ab-d]'); # '<-[ab..d]>'

# Compile textual ECMA262 regex into a Raku Regex object
my $regex = ECMA262Regex.compile('^fo+\n');

say "foo\n"  ~~ $regex; # Success
say " foo\n" ~~ $regex; # Failure
```
