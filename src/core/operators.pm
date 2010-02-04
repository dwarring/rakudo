our multi infix:<~~>(Mu $topic, Mu $matcher) {
    $matcher.ACCEPTS($topic)
}

our multi infix:<~~>(Mu $topic, Regex $matcher) {
    Q:PIR {
        $P0 = find_lex '$matcher'
        $P1 = find_lex '$topic'
        %r = $P0.'ACCEPTS'($P1)
        store_dynamic_lex '$/', %r
    };
}

our multi infix:<!~~>(Mu $topic, Mu $matcher) {
    $matcher.REJECTS($topic)
}

our multi sub prefix:<->($a) {
    pir::box__PN(pir::neg__NN($a))
}

our multi sub infix:<+>($a, $b) {
    pir::box__PN(pir::add__NNN($a, $b))
}

our multi sub infix:<->($a, $b) {
    pir::box__PN(pir::sub__NNN($a, $b))
}

our multi sub infix:<*>($a, $b) {
    pir::box__PN(pir::mul__NNN($a, $b))
}

our multi sub infix:</>($a, $b) {
    pir::box__PN(pir::div__NNN($a, $b))
}

our multi sub infix:<%>($a, $b) {
    pir::box__PN(pir::mod__NNN($a, $b))
}

our multi sub infix:<**>($a, $b) {
    pir::box__PN(pir::pow__NNN($a, $b))
}

our multi sub infix:<&>(*@items) {
    Junction.new(@items, :all)
}

our multi sub infix:<|>(*@items) {
    Junction.new(@items, :any)
}

our multi sub infix:<^>(*@items) {
    Junction.new(@items, :one)
}

our sub all(*@items) {
    Junction.new(@items, :all);
}

our sub any(*@items) {
    Junction.new(@items, :any);
}

our sub one(*@items) {
    Junction.new(@items, :one);
}

our sub none(*@items) {
    Junction.new(@items, :none);
}

our multi prefix:<not>($x) { !$x }

our multi prefix:<so>($x) { ?$x }

our sub undefine(\$x) {
    my $undefined;
    $x = $undefined;
}

our multi infix:<does>(Mu \$do-it-to-me, Role $r) {
    my $specific_role = $r!select;
    my $applicator    = $specific_role.^applier_for($do-it-to-me);
    $applicator.apply($do-it-to-me, [$r]);
    $do-it-to-me
}

our multi infix:<but>(Mu $do-it-to-me is copy, \$r) {
    $do-it-to-me does $r
}

our multi infix:<before>($a, $b) {
    ($a cmp $b) == -1;
}

our multi infix:<after>($a, $b) {
    ($a cmp $b) == +1;
}

our multi infix:<?|>($a, $b) {
    ?pir::bor__III($a, $b)
}

our multi infix:<?&>($a, $b) {
    ?pir::band__III($a, $b)
}

our multi infix:<?^>($a, $b) {
    ?pir::bxor__III($a, $b)
}

our multi infix:<min>($a, $b) {
    $a before $b ?? $a !! $b;
}

our multi infix:<max>($a, $b) {
    $a after $b ?? $a !! $b;
}
