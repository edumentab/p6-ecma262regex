### ECMA262Regex

This module allows you parsing ECMA262 regex notation and use it in Perl 6.

### SYNOPSIS

```
use v6;
use ECMA262Regex;

say ECMA262Regex.validate('\e'); # False;
say ECMA262Regex.validate('^fo+\n'); # True

# Translate regex inro Perl 6 one (string form)
say ECMA262Regex.as-perl6('^fo+\n'); # '^fo+\n'
say ECMA262Regex.as-perl6('[^ab-d]'); # '<-[ab..d]>'

my $regex = ECMA262Regex.compile('^fo+\n');

say "foo\n"  ~~ $regex; # Success
say " foo\n" ~~ $regex; # Failure
```
