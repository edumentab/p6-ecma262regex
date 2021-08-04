use v6;

my %control-char-to-unicode-name =
    A => <START OF HEADING>,
    B => <START OF TEXT>,
    C => <END OF TEXT>,
    D => <END OF TRANSMISSION>,
    E => <ENQUIRY>,
    F => <ACKNOWLEDGE>,
    G => <BELL>,
    H => <BACKSPACE>,
    I => <HORIZONTAL TABULATION>,
    J => <LINE FEED>,
    K => <VERTICAL TABULATION>,
    L => <FORM FEED>,
    M => <CARRIAGE RETURN>,
    N => <SHIFT OUT>,
    O => <SHIFT IN>,
    P => <DATA LINK ESCAPE>,
    Q => <DEVICE CONTROL ONE>,
    R => <DEVICE CONTROL TWO>,
    S => <DEVICE CONTROL THREE>,
    T => <DEVICE CONTROL FOUR>,
    U => <NEGATIVE ACKNOWLEDGE>,
    V => <SYNCHRONOUS IDLE>,
    W => <END OF TRANSMISSION BLOCK>,
    X => <CANCEL>,
    Y => <END OF MEDIUM>,
    Z => <SUBSTITUTE>;

grammar ECMA262Regex::Parser {
    token TOP {
        <disjunction>
    }
    token disjunction {
        <alternative>* % '|'
    }
    token alternative {
        <term>*
    }
    token term {
        <!before $>
        [
            | <assertion>
            | <atom> <quantifier>?
        ]
    }
    token assertion {
        | $<start>='^'
        | $<end>='$'
        | '\\' $<bound>=<[bB]>
        | $<poslook>='(?=' <disjunction> ')'
        | $<neglook>='(?!' <disjunction> ')'
    }
    token quantifier {
        <quantifier-prefix> [$<frugal>='?']?
    }
    token quantifier-prefix {
        | '+'
        | '*'
        | '?'
        | '{' <from=decimal-digits> [ $<upto>=',' <to=decimal-digits>? ]? '}'
    }
    token atom {
        | <pattern-character>
        | $<any>='.'
        | '\\' <atom-escape>
        | <character-class>
        | $<capture>='(' <disjunction> ')'
        | $<group>='(?:' <disjunction> ')'
    }
    token pattern-character {
        <-[^$\\.*+?()[\]{}|]>
    }
    token atom-escape {
        | <decimal-digits>
        | <character-escape>
        | <character-class-escape>
    }
    token character-escape {
        | <control-escape>
        | 'c' <control-letter>
        | <hex-escape-sequence>
        | <unicode-escape-sequence>
        | <identity-escape>
    }
    token control-escape {
        <[fnrtv]>
    }
    token control-letter {
        <[A..Za..z]>
    }
    token hex-escape-sequence {
        'x' <[0..9A..Fa..f]>**2
    }
    token unicode-escape-sequence {
        'u' <[0..9A..Fa..f]>**4
    }
    token identity-escape {
        <-ident-[\c[ZWJ]\c[ZWNJ]]>
    }
    token decimal-digits {
        <[0..9]>+
    }
    token character-class-escape {
        <[dDsSwW]>
    }
    token character-class {
        '[' '^'? <class-ranges> ']'
    }
    token class-ranges {
        <non-empty-class-ranges>?
    }
    token non-empty-class-ranges {
        | <class-atom> '-' <class-atom> <class-ranges>
        | <class-atom-no-dash> <non-empty-class-ranges-no-dash>?
        | <class-atom>
    }
    token non-empty-class-ranges-no-dash {
        | <class-atom-no-dash> '-' <class-atom> <class-ranges>
        | <class-atom-no-dash> <non-empty-class-ranges-no-dash>
        | <class-atom>
    }
    token class-atom {
        | '-'
        | <class-atom-no-dash>
    }
    token class-atom-no-dash {
        | <-[\\\]-]>
        | \\ <class-escape>
    }
    token class-escape {
        | <decimal-digits>
        | 'b'
        | <character-escape>
        | <character-class-escape>
    }
}

class ECMA262Regex::ToRakuRegex {
    method TOP($/) {
        make $<disjunction>.made;
    }

    method disjunction($/) {
        make $<alternative>>>.made.join(' || ');
    }

    method alternative($/) {
        make $<term>>>.made.join;
    }

    method term($/) {
        with $<assertion> {
            make $<assertion>.made;
        } else {
            my $atom = $<atom>.made;
            with $<quantifier> {
                make $atom ~ $<quantifier>.made;
            } else {
                make $atom;
            }
        }
    }

    method assertion($/) {
        given ~$/ {
            when '^'|'$' { make ~$/ }
            when '\\b'   { make "<|w>" }
            when '\\B'   { make "<!|w>" }
            when *.starts-with('(?=') { make '<?before ' ~ $<disjunction>.made ~ '>' }
            when *.starts-with('(?!') { make '<!before ' ~ $<disjunction>.made ~ '>' }
        }
    }

    method quantifier($/) {
        if $/.Str.ends-with('?') {
            make $<quantifier-prefix>.made;
        } else {
            make $<quantifier-prefix>.made;
        }
    }

    method quantifier-prefix($/) {
        if not $/.Str.starts-with('{') {
            make ~$/;
        } else {
            # {n}
            if not $/.Str.contains(',') {
                make ' ** ' ~ ~$<decimal-digits>;
            } else {
                if $<decimal-digits>.elems == 1 {
                    make ' ** ' ~ $<decimal-digits>[0].Str ~ '..* ';
                } else {
                    make ' ** ' ~ $<decimal-digits>.map({ ~$_ }).join('..');
                }
            }
        }
    }

    method atom($/) {
        if $/.Str.starts-with('(?:') {
            make '[' ~ $<disjunction>.made ~ ']';
            return;
        } elsif $/.Str.starts-with('(') {
            make '(' ~ $<disjunction>.made ~ ')';
            return;
        } elsif $/.Str eq '.' {
            make '.';
            return;
        }

        with $<pattern-character> {
            make $<pattern-character>.made;
        }
        orwith $<atom-escape> {
            make $<atom-escape>.made;
        }
        orwith $<character-class> {
            make $<character-class>.made;
        }
    }

    method pattern-character($/) {
        make $/.Str.ords.map({ "\\x" ~ .base(16) }).join;
    }

    method atom-escape($/) {
        with $<decimal-digits> {
            my $num = $<decimal-digits>.made.Int;
            make '$' ~ --$num;
        }
        orwith $<character-escape> {
            make $<character-escape>.made;
        } else {
            make '\\' ~ $<character-class-escape>.made;
        }
    }

    method character-escape($/) {
        with $<control-escape> {
            make $<control-escape>.made;
        }
        orwith $<control-letter> {
            make $<control-letter>.made;
        }
        orwith $<hex-escape-sequence> {
            make $<hex-escape-sequence>.made;
        }
        orwith $<unicode-escape-sequence> {
            make $<unicode-escape-sequence>.made;
        }
        orwith $<identity-escape> {
            make $<identity-escape>.made;
        }
    }

    method control-escape($/) {
        if $/.Str.ends-with("v") {
            make "\c[VERTICAL TABULATION]"
        } else {
            make '\\' ~ $/.Str;
        }
    }

    method control-letter($/) {
        my $name = %control-char-to-unicode-name{~$/};
        without $name {
            die 'Unknown control character escape is present: ' ~ $/.Str;
        }
        make '"\c[' ~ $name ~ ']"';
    }

    method hex-escape-sequence($/) {
        make '\x' ~ $/.Str.substr(1);
    }

    method unicode-escape-sequence($/) {
        make '\x' ~ $/.Str.substr(1);
    }

    method identity-escape($/) {
        make '\\' ~ $/.Str;
    }

    method decimal-digits($/) {
        make ~$/;
    }

    method character-class-escape($/) {
        make ~$/;
    }

    method character-class($/) {
        my $start = '<';
        $start ~= '-' if $/.Str.starts-with('[^');
        $start ~= '[' ~ $<class-ranges>.made;
        make $start ~ ']>';
    }

    method class-ranges($/) {
        with $<non-empty-class-ranges> {
            make $<non-empty-class-ranges>.made;
        } else { make '' }
    }

    method non-empty-class-ranges($/) {
        with $<class-ranges> {
            make $<class-atom>[0].made ~ '..' ~ $<class-atom>[1].made ~ $<class-ranges>.made;
        } orwith $<class-atom-no-dash> {
            my $class = $<class-atom-no-dash>.made;
            with $<non-empty-class-ranges-no-dash> {
                $class ~= $<non-empty-class-ranges-no-dash>.made;
            }
            make $class;
        } else {
            make $<class-atom>>>.made;
        }
    }

    method non-empty-class-ranges-no-dash($/) {
        with $<class-ranges> {
            make $<class-atom-no-dash>.made ~ '..' ~ $<class-atom>.made ~ $<class-ranges>.made;
        } orwith $<class-atom> {
            make $<class-atom>.made;
        } else {
            make $<class-atom-no-dash> ~ ' ' ~ $<non-empty-class-ranges-no-dash>.made;
        }
    }

    method class-atom($/) {
        if $/.Str eq '-' {
            make '-';
        } else {
            make $<class-atom-no-dash>.made;
        }
    }

    method class-atom-no-dash($/) {
        with $<class-escape> {
            make $<class-escape>.made;
        } else {
            make ~$/;
        }
    }

    method class-escape($/) {
        with $<decimal-digits> {
            my $num = $<decimal-digits>.made.Int;
            make '$' ~ --$num;
        } orwith $<character-escape> {
            make $<character-escape>.made;
        } orwith $<character-class-escape> {
            make '\\' ~ $<character-class-escape>.made;
        } else {
            make "<|w>";
        }
    }
}

class ECMA262Regex::ToRakuAST {
    method TOP($/) {
        make RakuAST::QuotedRegex.new(body => $<disjunction>.made);
    }

    method disjunction($/) {
        my @branches = $<alternative>>>.made;
        make @branches == 1
                ?? @branches[0]
                !! RakuAST::Regex::SequentialAlternation.new(|@branches);
    }

    method alternative($/) {
        my @terms = $<term>>>.made;
        make @terms == 1
            ?? @terms[0]
            !! RakuAST::Regex::Sequence.new(|@terms);
    }

    method term($/) {
        with $<atom> {
            my $atom = $<atom>.made;
            with $<quantifier> {
                make RakuAST::Regex::QuantifiedAtom.new:
                        :$atom, :quantifier(.made);
            }
            else {
                make $atom;
            }
        }
        else {
            make $<assertion>.made;
        }
    }

    method quantifier($/) {
        my $backtrack = $<frugal>
                ?? RakuAST::Regex::Backtrack::Frugal
                !! RakuAST::Regex::Backtrack::Greedy;
        given $<quantifier-prefix> {
            when .<from> && .<upto> {
                make RakuAST::Regex::Quantifier::Range.new:
                        :min(+.<from>), :max(+.<to> // Int), :$backtrack;
            }
            when .<from> {
                make RakuAST::Regex::Quantifier::Range.new:
                        :min(+.<from>), :max(+.<from>), :$backtrack;
            }
            when '+' {
                make RakuAST::Regex::Quantifier::OneOrMore.new: :$backtrack;
            }
            when '*' {
                make RakuAST::Regex::Quantifier::ZeroOrMore.new: :$backtrack
            }
            when '?' {
                make RakuAST::Regex::Quantifier::ZeroOrOne.new: :$backtrack
            }
        }
    }

    method assertion($/) {
        with $<poslook> orelse $<neglook> {
            my $name := RakuAST::Name.from-identifier('before');
            my $assertion = RakuAST::Regex::Assertion::Named::RegexArg.new:
                    :$name, :!capturing, :regex-arg($<disjunction>.ast);
            my $negated = ?$<neglook>;
            make RakuAST::Regex::Assertion::Lookahead.new(:$assertion, :$negated);
        }
        orwith $<start> {
            make RakuAST::Regex::Anchor::BeginningOfString.new;
        }
        orwith $<end> {
            make RakuAST::Regex::Anchor::EndOfString.new;
        }
        else {
            !!! 'nyi'
        }
    }

    method atom($/) {
        with $<pattern-character> orelse $<atom-escape> orelse $<character-class> {
            make .made;
        }
        orwith $<any> {
            make RakuAST::Regex::CharClass::Any.new;
        }
        orwith $<capture> {
            make RakuAST::Regex::CapturingGroup.new($<disjunction>.made);
        }
        orwith $<group> {
            make RakuAST::Regex::Group.new($<disjunction>.made);
        }
        else {
            !!! "Unrecognized atom"
        }
    }

    method pattern-character($/) {
        make RakuAST::Regex::Literal.new(~$/);
    }

    method atom-escape($/) {
        with $<character-class-escape> orelse $<character-escape> {
            make .made;
        }
        else {
            !!! "nyi"
        }
    }

    method character-escape($/) {
        make $/.caps[0].value.made;
    }

    method control-escape($/) {
        make do given $/ {
            when 'f' {
                RakuAST::Regex::CharClass::FormFeed.new
            }
            when 'n' {
                RakuAST::Regex::CharClass::Newline.new
            }
            when 'r' {
                RakuAST::Regex::CharClass::CarriageReturn.new
            }
            when 't' {
                RakuAST::Regex::CharClass::Tab.new
            }
            when 'v' {
                RakuAST::Regex::Literal.new("\c[VERTICAL TABULATION]")
            }
            default {
                die "Unexpected control escape '$_'";
            }
        }
    }

    method control-letter($/) {
        with %control-char-to-unicode-name{~$/} {
            make RakuAST::Regex::Literal.new(uniparse($_));
        }
        else {
            die 'Unknown control character escape is present: ' ~ $/.Str;
        }
    }

    method hex-escape-sequence($/) {
        make RakuAST::Regex::Literal.new($/.Str.substr(1).base(16).chr);
    }

    method unicode-escape-sequence($/) {
        make RakuAST::Regex::Literal.new($/.Str.substr(1).base(16).chr);
    }

    method identity-escape($/) {
        make RakuAST::Regex::Literal.new($/.Str);
    }

    method character-class-escape($/) {
        my constant ESCAPES = {
            d => RakuAST::Regex::CharClass::Digit,
            s => RakuAST::Regex::CharClass::Space,
            w => RakuAST::Regex::CharClass::Word
        };
        make ESCAPES{.lc}.new(:negated($_ eq .uc)) given ~$/;
    }
}

class ECMA262Regex {
    method validate($str) {
        so ECMA262Regex::Parser.parse($str);
    }

    method as-perl6($str) {
        self.as-raku($str)
    }

    method as-raku($str) {
        my $regex = ECMA262Regex::Parser.parse($str, actions => ECMA262Regex::ToRakuRegex);
        without $regex {
            die 'Regex is not valid!';
        }
        $regex.made;
    }

    method as-ast($str) {
        my $regex = ECMA262Regex::Parser.parse($str, actions => ECMA262Regex::ToRakuAST);
        without $regex {
            die 'Regex is not valid!';
        }
        $regex.made
    }

    method compile($regex) {
        use MONKEY-SEE-NO-EVAL;
        EVAL self.as-ast($regex)
    }
}
