# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use File::Path;

BEGIN { $| = 1; print "1..8\n"; }
END {print "not ok 1\n" unless $loaded;}
use Dir::Purge;
$loaded = 1;
print "ok 1\n";

# Cleanup the test directory and re-create it.
rmtree (['t1'], 1, 0);
mkdir ('t1', 0777);

# Put in the test files.
my $now = time - 1000;
for ( qw(f1 f6 f3 f2 f5 f4) ) {
    my $f = "t1/$_";
    open (F, ">$f") or warn ("$f: $!\n");
    print F ("$f\n");
    close (F);
    $now += 60;
    utime ($now, $now, $f) or warn ("$f: $!\n");
    warn ("$f: ",
	  (stat($f))[9], " ", $now, " ",
	  "Oops!\n") unless abs((stat($f))[9] - $now) < 30;
}

# Check existence of directory and files.
opendir (D, "t1") or print "not ";
print "ok 2\n";

my @files = grep {!/^\./} readdir(D);
closedir (D);

print "not " unless @files == 6;
print "ok 3\n";

print "not " unless join(" ",sort @files) eq "f1 f2 f3 f4 f5 f6";
print "ok 4\n";

# Test dirpurge. Nothing should be changed.
eval {
    purgedir ({verbose => 0, test => 1, keep => 4}, "t1");
};
print "$@\nnot " if $@;
print "ok 5\n";

# Verify directory and files.
opendir (D, "t1");
@files = grep {!/^\./} readdir(D);
closedir (D);
unless ( join(" ",sort @files) eq "f1 f2 f3 f4 f5 f6" ) {
    print "@files\n";
    print "not ";
}
print "ok 6\n";

# Now for the real work...
eval {
    purgedir ({verbose => 0, keep => 4}, "t1");
};
print "$@\nnot " if $@;
print "ok 7\n";

# Check that only the 4 most recent files are kept.
opendir (D, "t1");
@files = grep {!/^\./} readdir(D);
closedir (D);
unless ( join(" ",sort @files) eq "f2 f3 f4 f5" ) {
    print "@files\n";
    print "not ";
}
print "ok 8\n";

# Remove the test deirectory again.
rmtree (['t1']);

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

