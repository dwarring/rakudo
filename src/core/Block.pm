my class Block { # declared in BOOTSTRAP
    # class Block is Code {
    #     has Mu $!phasers;

    method add_phaser(Str $name, &block) {
        nqp::isnull($!phasers) &&
            nqp::bindattr(self, Block, '$!phasers', nqp::hash());
        nqp::existskey($!phasers, nqp::unbox_s($name)) ||
            nqp::bindkey($!phasers, nqp::unbox_s($name), nqp::list());
        if $name eq any(<LEAVE KEEP UNDO>) {
            nqp::unshift(nqp::atkey($!phasers, nqp::unbox_s($name)), &block);
            self.add_phaser('!LEAVE-ORDER', &block);
        }
        elsif $name eq any(<NEXT !LEAVE-ORDER POST>) {
            nqp::unshift(nqp::atkey($!phasers, nqp::unbox_s($name)), &block);
        }
        else {
            nqp::push(nqp::atkey($!phasers, nqp::unbox_s($name)), &block);
        }
    }

    method fire_phasers(str $name) {
        if !nqp::isnull($!phasers) && nqp::existskey($!phasers, $name) {
            my Mu $iter := nqp::iterator(nqp::atkey($!phasers, $name));
            nqp::shift($iter).() while $iter;
        }
    }
    
    method phasers(Str $name) {
        unless nqp::isnull($!phasers) {
            if nqp::existskey($!phasers, nqp::unbox_s($name)) {
                return nqp::p6parcel(nqp::atkey($!phasers, nqp::unbox_s($name)), Mu);
            }
        }
        ()
    }

    multi method perl(Block:D:) {
        my $perl = '-> ';
        $perl ~= self.signature().perl.substr(1); # lose colon prefix
        $perl ~= ' { #`(' ~ self.WHICH ~ ') ... }';
        $perl
    }
}

# vim: ft=perl6 expandtab sw=4
