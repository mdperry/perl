
BEGIN { unshift @INC, '[-.lib]'; }

my $Invoke_Perl = qq(MCR $^X "-I[-.lib]");

require "test.pl";
plan(tests => 24);

#========== vmsish status ==========
`$Invoke_Perl -e 1`;  # Avoid system() from a pipe from harness.  Mutter.
is($?,0,"simple Perl invokation: POSIX success status");
{
  use vmsish qw(status);
  is(($? & 1),1, "importing vmsish [vmsish status]");
  {
    no vmsish qw(status); # check unimport function
    is($?,0, "unimport vmsish [POSIX STATUS]");
  }
  # and lexical scoping
  is(($? & 1),1,"lex scope of vmsish [vmsish status]");
}
is($?,0,"outer lex scope of vmsish [POSIX status]");

{
  use vmsish qw(exit);  # check import function
  is($?,0,"importing vmsish exit [POSIX status]");
}

#========== vmsish exit, messages ==========
{
  use vmsish qw(status);

  $msg = do_a_perl('-e "exit 1"');
    $msg =~ s/\n/\\n/g; # keep output on one line
  like($msg,'ABORT', "POSIX ERR exit, DCL error message check");
  is($?&1,0,"vmsish status check, POSIX ERR exit");

  $msg = do_a_perl('-e "use vmsish qw(exit); exit 1"');
    $msg =~ s/\n/\\n/g; # keep output on one line
  ok(length($msg)==0,"vmsish OK exit, DCL error message check");
  is($?&1,1, "vmsish status check, vmsish OK exit");

  $msg = do_a_perl('-e "use vmsish qw(exit); exit 44"');
    $msg =~ s/\n/\\n/g; # keep output on one line
  like($msg, 'ABORT', "vmsish ERR exit, DCL error message check");
  is($?&1,0,"vmsish ERR exit, vmsish status check");

  $msg = do_a_perl('-e "use vmsish qw(hushed); exit 1"');
  $msg =~ s/\n/\\n/g; # keep output on one line
  ok(($msg !~ /ABORT/),"POSIX ERR exit, vmsish hushed, DCL error message check");

  $msg = do_a_perl('-e "use vmsish qw(exit hushed); exit 44"');
    $msg =~ s/\n/\\n/g; # keep output on one line
  ok(($msg !~ /ABORT/),"vmsish ERR exit, vmsish hushed, DCL error message check");

  $msg = do_a_perl('-e "use vmsish qw(exit hushed); no vmsish qw(hushed); exit 44"');
  $msg =~ s/\n/\\n/g; # keep output on one line
  like($msg,'ABORT',"vmsish ERR exit, no vmsish hushed, DCL error message check");

  $msg = do_a_perl('-e "use vmsish qw(hushed); die(qw(blah));"');
  $msg =~ s/\n/\\n/g; # keep output on one line
  ok(($msg !~ /ABORT/),"die, vmsish hushed, DCL error message check");

  $msg = do_a_perl('-e "use vmsish qw(hushed); use Carp; croak(qw(blah));"');
  $msg =~ s/\n/\\n/g; # keep output on one line
  ok(($msg !~ /ABORT/),"croak, vmsish hushed, DCL error message check");

  $msg = do_a_perl('-e "use vmsish qw(exit); vmsish::hushed(1); exit 44;"');
  $msg =~ s/\n/\\n/g; # keep output on one line
  ok(($msg !~ /ABORT/),"vmsish ERR exit, vmsish hushed at runtime, DCL error message check");

  local *TEST;
  open(TEST,'>vmsish_test.pl') || die('not ok ?? : unable to open "vmsish_test.pl" for writing');  
  print TEST "#! perl\n";
  print TEST "use vmsish qw(hushed);\n";
  print TEST "\$obvious = (\$compile(\$error;\n";
  close TEST;
  $msg = do_a_perl('vmsish_test.pl');
  $msg =~ s/\n/\\n/g; # keep output on one line
  ok(($msg !~ /ABORT/),"compile ERR exit, vmsish hushed, DCL error message check");
  unlink 'vmsish_test.pl';
}


#========== vmsish time ==========
{
  my($utctime, @utclocal, @utcgmtime, $utcmtime,
     $vmstime, @vmslocal, @vmsgmtime, $vmsmtime,
     $utcval,  $vmaval, $offset);
  # Make sure apparent local time isn't GMT
  if (not $ENV{'SYS$TIMEZONE_DIFFERENTIAL'}) {
    $oldtz = $ENV{'SYS$TIMEZONE_DIFFERENTIAL'};
    $ENV{'SYS$TIMEZONE_DIFFERENTIAL'} = 3600;
    eval "END { \$ENV{'SYS\$TIMEZONE_DIFFERENTIAL'} = $oldtz; }";
    gmtime(0); # Force reset of tz offset
  }
  {
     use_ok('vmsish qw(time)');
     $vmstime   = time;
     @vmslocal  = localtime($vmstime);
     @vmsgmtime = gmtime($vmstime);
     $vmsmtime  = (stat $0)[9];
  }
  $utctime   = time;
  @utclocal  = localtime($vmstime);
  @utcgmtime = gmtime($vmstime);
  $utcmtime  = (stat $0)[9];
  
  $offset = $ENV{'SYS$TIMEZONE_DIFFERENTIAL'};

  # We allow lots of leeway (10 sec) difference for these tests,
  # since it's unlikely local time will differ from UTC by so small
  # an amount, and it renders the test resistant to delays from
  # things like stat() on a file mounted over a slow network link.
  ok($utctime - $vmstime +$offset <= 10,"(time) UTC:$utctime VMS:$vmstime");

  $utcval = $utclocal[5] * 31536000 + $utclocal[7] * 86400 +
            $utclocal[2] * 3600     + $utclocal[1] * 60 + $utclocal[0];
  $vmsval = $vmslocal[5] * 31536000 + $vmslocal[7] * 86400 +
            $vmslocal[2] * 3600     + $vmslocal[1] * 60 + $vmslocal[0];
  ok($vmsval - $utcval + $offset <= 10, "(localtime)\n# UTC: @utclocal\n# VMS: @vmslocal");

  $utcval = $utcgmtime[5] * 31536000 + $utcgmtime[7] * 86400 +
            $utcgmtime[2] * 3600     + $utcgmtime[1] * 60 + $utcgmtime[0];
  $vmsval = $vmsgmtime[5] * 31536000 + $vmsgmtime[7] * 86400 +
            $vmsgmtime[2] * 3600     + $vmsgmtime[1] * 60 + $vmsgmtime[0];
  ok($vmsval - $utcval + $offset <= 10, "(gmtime)\n# UTC: @utcgmtime\n# VMS: @vmsgmtime");

  ok($vmsmtime - $utcmtime + $offset <= 10,"(stat) UTC: $utcmtime  VMS: $vmsmtime");
}

#====== need this to make sure error messages come out, even if
#       they were turned off in invoking procedure
sub do_a_perl {
    local *P;
    open(P,'>vmsish_test.com') || die('not ok ?? : unable to open "vmsish_test.com" for writing');
    print P "\$ set message/facil/sever/ident/text\n";
    print P "\$ define/nolog/user sys\$error _nla0:\n";
    print P "\$ $Invoke_Perl @_\n";
    close P;
    my $x = `\@vmsish_test.com`;
    unlink 'vmsish_test.com';
    return $x;
}

