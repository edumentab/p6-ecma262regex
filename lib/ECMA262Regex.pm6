use v6;

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
        | '^'
        | '$'
        | '\\' <[bB]>
        | '(?=' <disjunction> ')'
        | '(?!' <disjunction> ')'
    }
    token quantifier {
        <quantifier-prefix> '?'?
    }
    token quantifier-prefix {
        | '+'
        | '*'
        | '?'
        | '{' <decimal-digits> [ ',' <decimal-digits>? ]? '}'
    }
    token atom {
        | <pattern-character>
        | '.'
        | '\\' <atom-escape>
        | <character-class>
        | '(' <disjunction> ')'
        | '(?:' <disjunction> ')'
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
