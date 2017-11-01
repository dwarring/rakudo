# Provide an API for keeping track of a lot of system lifesigns

use nqp;

# Constants indexing into the nqp::getrusage array -----------------------------
constant UTIME_SEC  = 0;
constant UTIME_MSEC = 1;
constant STIME_SEC  = 2;
constant STIME_MSEC = 3;
constant MAX_RSS    = 4;
constant IX_RSS     = 5;
constant ID_RSS     = 6;

# Helper stuff -----------------------------------------------------------------
my num $start = Rakudo::Internals.INITTIME;

sub completed(\workers) is raw {
    my int $elems = nqp::elems(workers);
    my int $completed;
    my int $i = -1;
    nqp::while(
      nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
      nqp::stmts(
        (my $w := nqp::atpos(workers,$i)),
        ($completed = nqp::add_i(
          $completed,
          nqp::getattr_i($w,$w.WHAT,'$!total')
        ))
      )
    );
    $completed
}

# Subroutines that are exported with :COLUMNS ----------------------------------
sub cpu() is raw is export(:COLUMNS) {
    my \rusage = nqp::getrusage;
    nqp::atpos_i(rusage,UTIME_SEC) * 1000000
      + nqp::atpos_i(rusage,UTIME_MSEC)
      + nqp::atpos_i(rusage,STIME_SEC) * 1000000
      + nqp::atpos_i(rusage,STIME_MSEC)
}

sub cpu-user() is raw is export(:COLUMNS) {
    my \rusage = nqp::getrusage;
    nqp::atpos_i(rusage,UTIME_SEC) * 1000000 + nqp::atpos_i(rusage,UTIME_MSEC)
}

sub cpu-sys() is raw is export(:COLUMNS) {
    my \rusage = nqp::getrusage;
    nqp::atpos_i(rusage,STIME_SEC) * 1000000 + nqp::atpos_i(rusage,STIME_MSEC)
}

sub max-rss() is raw is export(:COLUMNS) {
    nqp::atpos_i(nqp::getrusage,MAX_RSS)
}

sub ix-rss() is raw is export(:COLUMNS) {
    nqp::atpos_i(nqp::getrusage,IX_RSS)
}

sub id-rss() is raw is export(:COLUMNS) {
    nqp::atpos_i(nqp::getrusage,ID_RSS)
}

sub wallclock() is raw is export(:COLUMNS) {
    nqp::fromnum_I(1000000 * nqp::sub_n(nqp::time_n,$start),Int)
}

sub supervisor() is raw is export(:COLUMNS) {
    nqp::istrue(
      nqp::getattr(nqp::decont($*SCHEDULER),ThreadPoolScheduler,'$!supervisor')
    )
}

sub general-workers() is raw is export(:COLUMNS) {
    nqp::if(
      nqp::istrue((my $workers := nqp::getattr(
        nqp::decont($*SCHEDULER),ThreadPoolScheduler,'$!general-workers'
      ))),
      nqp::elems($workers)
    )
}

sub general-tasks-queued() is raw is export(:COLUMNS) {
    nqp::if(
      nqp::istrue((my $queue := nqp::getattr(
        nqp::decont($*SCHEDULER),ThreadPoolScheduler,'$!general-queue'
      ))),
      nqp::elems($queue)
    )
}

sub general-tasks-completed() is raw is export(:COLUMNS) {
    nqp::if(
      nqp::istrue((my $workers := nqp::getattr(
        nqp::decont($*SCHEDULER),ThreadPoolScheduler,'$!general-workers'
      ))),
      completed($workers)
    )
}

sub timer-workers() is raw is export(:COLUMNS) {
    nqp::if(
      nqp::istrue((my $workers := nqp::getattr(
        nqp::decont($*SCHEDULER),ThreadPoolScheduler,'$!timer-workers'
      ))),
      nqp::elems($workers)
    )
}

sub timer-tasks-queued() is raw is export(:COLUMNS) {
    nqp::if(
      nqp::istrue((my $queue := nqp::getattr(
        nqp::decont($*SCHEDULER),ThreadPoolScheduler,'$!timer-queue'
      ))),
      nqp::elems($queue)
    )
}

sub timer-tasks-completed() is raw is export(:COLUMNS) {
    nqp::if(
      nqp::istrue((my $workers := nqp::getattr(
        nqp::decont($*SCHEDULER),ThreadPoolScheduler,'$!timer-workers'
      ))),
      completed($workers)
    )
}

sub affinity-workers() is raw is export(:COLUMNS) {
    nqp::if(
      nqp::istrue((my $workers := nqp::getattr(
        nqp::decont($*SCHEDULER),ThreadPoolScheduler,'$!affinity-workers'
      ))),
      nqp::elems($workers)
    )
}

# Telemetry --------------------------------------------------------------------
class Telemetry {
    has int $!cpu-user;
    has int $!cpu-sys;
    has int $!max-rss;
    has int $!ix-rss;
    has int $!id-rss;
    has int $!wallclock;
    has int $!supervisor;
    has int $!general-workers;
    has int $!general-tasks-queued;
    has int $!general-tasks-completed;
    has int $!timer-workers;
    has int $!timer-tasks-queued;
    has int $!timer-tasks-completed;
    has int $!affinity-workers;

    submethod BUILD() {
        my \rusage = nqp::getrusage;
        $!cpu-user = nqp::atpos_i(rusage,UTIME_SEC) * 1000000
          + nqp::atpos_i(rusage,UTIME_MSEC);
        $!cpu-sys  = nqp::atpos_i(rusage,STIME_SEC) * 1000000
          + nqp::atpos_i(rusage,STIME_MSEC);
        $!max-rss  = nqp::atpos_i(rusage,MAX_RSS);
        $!ix-rss   = nqp::atpos_i(rusage,IX_RSS);
        $!id-rss   = nqp::atpos_i(rusage,ID_RSS);

        $!wallclock =
          nqp::fromnum_I(1000000 * nqp::sub_n(nqp::time_n,$start),Int);

        my $scheduler := nqp::decont($*SCHEDULER);
        $!supervisor = 1
          if nqp::getattr($scheduler,ThreadPoolScheduler,'$!supervisor');

        if nqp::getattr($scheduler,ThreadPoolScheduler,'$!general-workers')
          -> \workers {
            $!general-workers = nqp::elems(workers);
            $!general-tasks-completed = completed(workers);
        }
        if nqp::getattr($scheduler,ThreadPoolScheduler,'$!general-queue')
          -> \queue {
            $!general-tasks-queued = nqp::elems(queue);
        }
        if nqp::getattr($scheduler,ThreadPoolScheduler,'$!timer-workers')
          -> \workers {
            $!timer-workers = nqp::elems(workers);
            $!timer-tasks-completed = completed(workers);
        }
        if nqp::getattr($scheduler,ThreadPoolScheduler,'$!timer-queue')
          -> \queue {
            $!timer-tasks-queued = nqp::elems(queue);
        }
        if nqp::getattr($scheduler,ThreadPoolScheduler,'$!affinity-workers')
          -> \workers {
            $!affinity-workers = nqp::elems(workers);
        }

    }

    multi method cpu(Telemetry:U:) is raw { cpu }
    multi method cpu(Telemetry:D:) is raw { nqp::add_i($!cpu-user,$!cpu-sys) }

    multi method cpu-user(Telemetry:U:) is raw {   cpu-user }
    multi method cpu-user(Telemetry:D:) is raw { $!cpu-user }

    multi method cpu-sys(Telemetry:U:) is raw {   cpu-sys }
    multi method cpu-sys(Telemetry:D:) is raw { $!cpu-sys }

    multi method max-rss(Telemetry:U:) is raw {   max-rss }
    multi method max-rss(Telemetry:D:) is raw { $!max-rss }

    multi method ix-rss(Telemetry:U:) is raw {   ix-rss }
    multi method ix-rss(Telemetry:D:) is raw { $!ix-rss }

    multi method id-rss(Telemetry:U:) is raw {   id-rss }
    multi method id-rss(Telemetry:D:) is raw { $!id-rss }

    multi method wallclock(Telemetry:U:) is raw {   wallclock }
    multi method wallclock(Telemetry:D:) is raw { $!wallclock }

    multi method supervisor(Telemetry:U:) is raw {   supervisor }
    multi method supervisor(Telemetry:D:) is raw { $!supervisor }

    multi method general-workers(Telemetry:U:) is raw {   general-workers }
    multi method general-workers(Telemetry:D:) is raw { $!general-workers }

    multi method general-tasks-queued(Telemetry:U:) is raw {
        general-tasks-queued
    }
    multi method general-tasks-queued(Telemetry:D:) is raw {
        $!general-tasks-queued
    }

    multi method general-tasks-completed(Telemetry:U:) is raw {
        general-tasks-completed
    }
    multi method general-tasks-completed(Telemetry:D:) is raw {
        $!general-tasks-completed
    }

    multi method timer-workers(Telemetry:U:) is raw {   timer-workers }
    multi method timer-workers(Telemetry:D:) is raw { $!timer-workers }

    multi method timer-tasks-queued(Telemetry:U:) is raw {
        timer-tasks-queued
    }
    multi method timer-tasks-queued(Telemetry:D:) is raw {
        $!timer-tasks-queued
    }

    multi method timer-tasks-completed(Telemetry:U:) is raw {
        timer-tasks-completed
    }
    multi method timer-tasks-completed(Telemetry:D:) is raw {
        $!timer-tasks-completed
    }

    multi method affinity-workers(Telemetry:U:) {   affinity-workers }
    multi method affinity-workers(Telemetry:D:) { $!affinity-workers }

    multi method Str(Telemetry:D:) {
        "$.cpu / $!wallclock"
    }
    multi method gist(Telemetry:D:) {
        "$.cpu / $!wallclock"
    }
}

# Telemetry::Period ------------------------------------------------------------
class Telemetry::Period is Telemetry {

    # The external .new with slower named parameter interface
    multi method new(Telemetry::Period:
      int :$cpu-user,
      int :$cpu-sys,
      int :$max-rss,
      int :$ix-rss,
      int :$id-rss,
      int :$wallclock,
      int :$supervisor,
      int :$general-workers,
      int :$general-tasks-queued,
      int :$general-tasks-completed,
      int :$timer-workers,
      int :$timer-tasks-queued,
      int :$timer-tasks-completed,
      int :$affinity-workers,
    ) {
        self.new(
          $cpu-user, $cpu-sys,
          $max-rss, $ix-rss, $id-rss,
          $wallclock, $supervisor,
          $general-workers, $general-tasks-queued, $general-tasks-completed,
          $timer-workers, $timer-tasks-queued, $timer-tasks-completed,
          $affinity-workers
        )
    }

    # The internal .new with faster positional parameter interface
    multi method new(Telemetry::Period:
      int $cpu-user,
      int $cpu-sys,
      int $max-rss,
      int $ix-rss,
      int $id-rss,
      int $wallclock,
      int $supervisor,
      int $general-workers,
      int $general-tasks-queued,
      int $general-tasks-completed,
      int $timer-workers,
      int $timer-tasks-queued,
      int $timer-tasks-completed,
      int $affinity-workers,
    ) {
        my $period := nqp::create(Telemetry::Period);
        nqp::bindattr_i($period,Telemetry,
          '$!cpu-user',               $cpu-user);
        nqp::bindattr_i($period,Telemetry,
          '$!cpu-sys',                $cpu-sys);
        nqp::bindattr_i($period,Telemetry,
          '$!max-rss',                $max-rss);
        nqp::bindattr_i($period,Telemetry,
          '$!ix-rss',                 $ix-rss);
        nqp::bindattr_i($period,Telemetry,
          '$!id-rss',                 $id-rss);
        nqp::bindattr_i($period,Telemetry,
          '$!wallclock',              $wallclock);
        nqp::bindattr_i($period,Telemetry,
          '$!supervisor',             $supervisor);
        nqp::bindattr_i($period,Telemetry,
          '$!general-workers',        $general-workers);
        nqp::bindattr_i($period,Telemetry,
          '$!general-tasks-queued',   $general-tasks-queued);
        nqp::bindattr_i($period,Telemetry,
          '$!general-tasks-completed',$general-tasks-completed);
        nqp::bindattr_i($period,Telemetry,
          '$!timer-workers',          $timer-workers);
        nqp::bindattr_i($period,Telemetry,
          '$!timer-tasks-queued',     $timer-tasks-queued);
        nqp::bindattr_i($period,Telemetry,
          '$!timer-tasks-completed',  $timer-tasks-completed);
        nqp::bindattr_i($period,Telemetry,
          '$!affinity-workers',       $affinity-workers);
        $period
    }

    # For roundtripping
    multi method perl(Telemetry::Period:D:) {
        "Telemetry::Period.new(:cpu-user({
          nqp::getattr_i(self,Telemetry,'$!cpu-user')
        }), :cpu-sys({
          nqp::getattr_i(self,Telemetry,'$!cpu-sys')
        }), :max-rss({
          nqp::getattr_i(self,Telemetry,'$!max-rss')
        }), :ix-rss({
          nqp::getattr_i(self,Telemetry,'$!ix-rss')
        }), :id-rss({
          nqp::getattr_i(self,Telemetry,'$!id-rss')
        }), :wallclock({
          nqp::getattr_i(self,Telemetry,'$!wallclock')
        }), :supervisor({
          nqp::getattr_i(self,Telemetry,'$!supervisor')
        }), :general-workers({
          nqp::getattr_i(self,Telemetry,'$!general-workers')
        }), :general-tasks-queued({
          nqp::getattr_i(self,Telemetry,'$!general-tasks-queued')
        }), :general-tasks-completed({
          nqp::getattr_i(self,Telemetry,'$!general-tasks-completed')
        }), :timer-workers({
          nqp::getattr_i(self,Telemetry,'$!timer-workers')
        }), :timer-tasks-queued({
          nqp::getattr_i(self,Telemetry,'$!timer-tasks-queued')
        }), :timer-tasks-completed({
          nqp::getattr_i(self,Telemetry,'$!timer-tasks-completed')
        }), :affinity-workers({
          nqp::getattr_i(self,Telemetry,'$!affinity-workers')
        }))"
    }

    method cpus() {
        nqp::add_i(
          nqp::getattr_i(self,Telemetry,'$!cpu-user'),
          nqp::getattr_i(self,Telemetry,'$!cpu-sys')
        ) / nqp::getattr_i(self,Telemetry,'$!wallclock')
    }

    my $factor = 100 / Kernel.cpu-cores;
    method utilization() { $factor * self.cpus }
}

# Creating Telemetry::Period objects -------------------------------------------
multi sub infix:<->(Telemetry:U \a, Telemetry:U \b) is export {
    nqp::create(Telemetry::Period)
}
multi sub infix:<->(Telemetry:D \a, Telemetry:U \b) is export { a - b.new }
multi sub infix:<->(Telemetry:U \a, Telemetry:D \b) is export { a.new - b }
multi sub infix:<->(Telemetry:D \a, Telemetry:D \b) is export {
    my $a := nqp::decont(a);
    my $b := nqp::decont(b);

    Telemetry::Period.new(
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!cpu-user'),
        nqp::getattr_i($b,Telemetry,'$!cpu-user')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!cpu-sys'),
        nqp::getattr_i($b,Telemetry,'$!cpu-sys')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!max-rss'),
        nqp::getattr_i($b,Telemetry,'$!max-rss')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!ix-rss'),
        nqp::getattr_i($b,Telemetry,'$!ix-rss')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!id-rss'),
        nqp::getattr_i($b,Telemetry,'$!id-rss')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!wallclock'),
        nqp::getattr_i($b,Telemetry,'$!wallclock')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!supervisor'),
        nqp::getattr_i($b,Telemetry,'$!supervisor')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!general-workers'),
        nqp::getattr_i($b,Telemetry,'$!general-workers')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!general-tasks-queued'),
        nqp::getattr_i($b,Telemetry,'$!general-tasks-queued')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!general-tasks-completed'),
        nqp::getattr_i($b,Telemetry,'$!general-tasks-completed')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!timer-workers'),
        nqp::getattr_i($b,Telemetry,'$!timer-workers')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!timer-tasks-queued'),
        nqp::getattr_i($b,Telemetry,'$!timer-tasks-queued')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!timer-tasks-completed'),
        nqp::getattr_i($b,Telemetry,'$!timer-tasks-completed')
      ),
      nqp::sub_i(
        nqp::getattr_i($a,Telemetry,'$!affinity-workers'),
        nqp::getattr_i($b,Telemetry,'$!affinity-workers')
      )
    )
}

# Subroutines that are always exported -----------------------------------------

# Making a Telemetry object procedurally 
my @snaps;
proto sub snap(|) is export { * }
multi sub snap(--> Nil)    { @snaps.push(Telemetry.new) }
multi sub snap(@s --> Nil) { @s.push(Telemetry.new) }

# Starting the snapper / changing the period size
my int $snapper-running;
my $snapper-wait;
sub snapper($sleep = 0.1 --> Nil) is export {
    $snapper-wait = $sleep;
    unless $snapper-running {
        snap;
        Thread.start(:app_lifetime, :name<Snapper>, {
            loop { sleep $snapper-wait; snap }
        });
        $snapper-running = 1
    }
}

# Telemetry::Period objects from a list of Telemetry objects
proto sub periods(|) is export { * }
multi sub periods() {
    my @s = @snaps;
    @snaps = ();
    @s.push(Telemetry.new) if @s == 1;
    periods(@s)
}
multi sub periods(@s) { (1..^@s).map: { @s[$_] - @s[$_ - 1] } }

# Telemetry reporting features -------------------------------------------------
proto sub report(|) is export { * }
multi sub report(:$legend, :$header-repeat = 32) {
    my $s := nqp::clone(nqp::getattr(@snaps,List,'$!reified'));
    nqp::setelems(nqp::getattr(@snaps,List,'$!reified'),0);
    nqp::push($s,Telemetry.new) if nqp::elems($s) == 1;
    report(
      nqp::p6bindattrinvres(nqp::create(List),List,'$!reified',$s),
      :$legend,
      :$header-repeat,
    );
}

# Convert to spaces if numeric value is 0
sub hide0(\value, int $size = 3) {
    value ?? value.fmt("%{$size}d") !! nqp::x(" ",$size)
}

# Set up how to handle report generation (in alphabetical order)
my %format =
  affinity-workers =>
    [     " aw", { hide0(.affinity-workers) },
      "The number of affinity threads"],
  cpu =>
    ["     cpu", { .cpu.fmt('%8d') },
      "The amount of CPU used (in microseconds)"],
  cpu-user =>
    ["cpu-user", { .cpu.fmt('%8d') },
      "The amount of CPU used in user code (in microseconds)"],
  cpu-sys =>
    [" cpu-sys", { .cpu.fmt('%8d') },
      "The amount of CPU used in system overhead (in microseconds)"],
  general-workers =>
    [     " gw", { hide0(.general-workers) },
      "The number of general worker threads"],
  general-tasks-queued =>
    [     "gtq", { hide0(.general-tasks-queued) },
      "The number of tasks queued for execution in general worker threads"],
  general-tasks-completed =>
    [ "     gtc", { hide0(.general-tasks-completed,8) },
      "The number of tasks completed in general worker threads"],
  id-rss =>
    ["    id-rss", { hide0(.id-rss,10) },
      "Integral unshared data size (in bytes)"],
  ix-rss =>
    ["    ix-rss", { hide0(.ix-rss,10) },
      "Integral shared text memory size (in bytes)"],
  max-rss =>
    ["   max-rss", { hide0(.max-rss,10) },
      "Maximum resident set size (in bytes)"],
  supervisor =>
    [       "s", { hide0(.supervisor,1) },
      "The number of supervisors"],
  timer-workers =>
    [     " tw", { hide0(.timer-workers) },
      "The number of timer threads"],
  timer-tasks-queued =>
    [     "ttq", { hide0(.timer-tasks-queued) },
      "The number of tasks queued for execution in timer threads"],
  timer-tasks-completed =>
    [ "     ttc", { hide0(.timer-tasks-completed,8) },
      "The number of tasks completed in timer threads"],
  utilization =>
    [  " util%", { .utilization.fmt('%6.2f') },
      "Percentage of CPU utilization (0..100%)"],
  wallclock =>
    ["wallclock", { .wallclock.fmt('%9d') },
      "Number of microseconds elapsed"],
;

# Set footer and make sure we can also use the header key as an indicator
for %format.values -> \v {
    v[3] = '-' x v[0].chars;
    %format{v[0].trim} = v;
}

multi sub report(
  @s,
  @cols = <wallclock util% max-rss gw gtc tw ttc aw>,
  :$legend,
  :$header-repeat = 32,
) {

    my $total = @s[*-1] - @s[0];
    my $text := nqp::list_s(qq:to/HEADER/.chomp);
Telemetry Report of Process #$*PID ({Instant.from-posix(nqp::time_i).DateTime})
Number of Snapshots: {+@s}
Total Time:      { ($total.wallclock / 1000000).fmt('%9.2f') } seconds
Total CPU Usage: { ($total.cpu / 1000000).fmt('%9.2f') } seconds
HEADER

    sub push-period($period) {
        nqp::push_s($text,
          %format{@cols}>>.[1]>>.($period).join(' ').trim-trailing);
    }

    my $header = "\n%format{@cols}>>.[0].join(' ')";
    nqp::push_s($text,$header) unless $header-repeat;

    for periods(@s).kv -> $index, $period {
        nqp::push_s($text,$header)
          if $header-repeat && $index %% $header-repeat;
        push-period($period)
    }

    nqp::push_s($text,%format{@cols}>>.[3].join(' '));

    push-period($total);

    if $legend {
        nqp::push_s($text,'');
        nqp::push_s($text,'Legend:');
        for %format{@cols} -> $col {
            nqp::push_s($text," $col[0].trim-leading.fmt('%9s')  $col[2]");
        }
    }

    nqp::join("\n",$text)
}

# Make sure we tell the world if we're implicitely told to do so ---------------
END { if @snaps { snap; note report(:legend) } }

# vim: ft=perl6 expandtab sw=4