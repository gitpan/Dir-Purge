# Dir::Purge.pm -- Purge directories
# RCS Info        : $Id: Purge.pm,v 1.1 2000-05-21 15:35:37+02 jv Exp $
# Author          : Johan Vromans
# Created On      : Wed May 17 12:58:02 2000
# Last Modified By: Johan Vromans
# Last Modified On: Sun May 21 15:35:19 2000
# Update Count    : 89
# Status          : Unknown, Use with caution!

package Dir::Purge;

use strict;
use Carp;

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
$VERSION    = "1.0";
@ISA        = qw(Exporter);
@EXPORT     = qw(&purgedir);
@EXPORT_OK  = qw(&purgedir_by_age);

my $verbose;			# verbosity. default = 1
my $keep;			# number of files to keep, no default
my $debug;			# debugging
my $test;			# testing only

my $purge_by_age;		# strategy

sub purgedir_by_age {
    my @dirs = @_;
    my $opts;
    if ( UNIVERSAL::isa ($dirs[0], 'HASH') ) {
	my $opts = shift (@dirs);
	my $strat = delete $opts->{strategy};
	if ( defined $strat && $strat ne "by_age" ) {
	    croak ("Invalid option: \"strategy\"");
	}
	$opts->{strategy} = "by_age";
    }
    else {
	$opts = { keep => shift(@dirs), strategy => "by_age" };
    }
    purgedir ($opts, @dirs);
}


# Common processing code. It verifies the arguments, directories and
# calls $code->(...) to do the actual purging.
# Nothing is done if any of the verifications fail.

sub purgedir {

    my (@dirs) = @_;
    my $error = 0;
    my $code = $purge_by_age;	# default: by age
    my $tag = "purgedir";

    # Get the parameters. Only the 'keep' value is mandatory.
    if ( UNIVERSAL::isa ($dirs[0], 'HASH') ) {
	my $opts  = shift (@dirs);
	$keep	  = delete $opts->{keep};
	$verbose  = delete $opts->{verbose};
	$test	  = delete $opts->{test};
	$debug	  = delete $opts->{debug};
	my $strat = delete $opts->{strategy};
	if ( defined $strat ) {
	    if ( $strat eq "by_age" ) {
		$code = $purge_by_age;
	    }
	    else {
		carp ("Unsupported purge strategy: \"$strat\"");
		$error++;
	    }
	}
	foreach (sort keys %$opts) {
	    carp ("Unhandled option \"$_\"");
	    $error++;
	}
    }
    elsif ( $dirs[0] =~ /^-?\d+$/ ) {
	$keep = shift (@dirs);
    }

    unless ( defined $keep && $keep ) {
	croak ("Missing 'keep' value");
    }

    $verbose = 1 unless defined ($verbose);
    $verbose++ if $debug;

    # Thouroughly check the directories, and refuse to do anything
    # in case of problems.
    warn ("$tag: checking directories\n") if $verbose;
    foreach my $dir ( @dirs ) {
	# Must be a directory.
	unless ( -d $dir ) {
	    carp (-e _ ? "$dir: not a directory" : "$dir: not existing");
	    $error++;
	    next;
	}
	# We need write access since we are going to delete files.
	unless ( -w _ ) {
	    carp ("$dir: no write access");
	    $error++;
	}
	# We need read acces since we are going to ge tthe file list.
	unless ( -r _ ) {
	    carp ("$dir: no read access");
	    $error++;
	}
	# Probably need this as weel, don't know.
	unless ( -x _ ) {
	    carp ("$dir: no access");
	    $error++;
	}
    }

    # If errors, bail out unless testing.
    if ( $error ) {
	if ( $test ) {
	    carp ("$tag: errors detected, continuing");
	}
	else {
	    croak ("$tag: errors detected, nothing done");
	}
    }

    # Process the directories.
    foreach my $dir ( @dirs ) {
	$code->($dir);
    }
};

# Processing routine: purge by file age.

$purge_by_age = sub {

    my $tag = "purgedir";
    my $dir = shift;
    warn ("$tag: purging directory $dir (by age, keep $keep)\n")
      if $verbose;

    # Gather file names and ages.
    opendir (DIR, $dir)
      or croak ("dir: $!");	# shouldn't happen -- we've checked!
    my @files;
    foreach ( readdir (DIR) ) {
	next if /^\./;
	next unless -f "$dir/$_";
	push (@files, [ "$dir/$_", -M _ ]);
    }
    closedir (DIR);

    warn ("$tag: $dir: ", scalar(@files), " files\n") if $verbose;
    warn ("$tag: $dir: @{[map { $_->[0] } @files]}\n") if $debug;

    # Is there anything to do?
    if ( @files <= abs($keep) ) {
	warn ("$tag: $dir: below limit\n") if $verbose;
	return;
    }

    # Sort on age. Also reduces the list to file names only.
    my @sorted = map { $_->[0] } sort { $b->[1] <=> $a->[1] } @files;
    warn ("$tag: $dir: sorted: @sorted\n") if $debug;

    # Splice out the files to keep.
    if ( $keep < 0 ) {
	# Keep the oldest files (head of the list).
	splice (@sorted, 0, -$keep);
    }
    else {
	# Keep the newest files (tail of the list).
	splice (@sorted, @sorted-$keep, $keep);
    }

    # Remove the rest.
    foreach ( @sorted ) {
	if ( $test ) {
	    warn ("$tag: candidate: $_\n");
	}
	else {
	    warn ("$tag: removing $_\n") if $verbose;
	    unlink ($_) or carp ("$dir: $!");
	}
    }
};

1;

__END__

=head1 NAME

Dir::Purge - Purge directories to a given number of files.

=head1 SYNOPSIS

  perl -MDir::Purge -e 'purgedir (5, @ARGV)' /spare/backups

  use Dir::Purge;
  purgedir ({keep => 5, strategy => "by_age", verbose => 1}, "/spare/backups");

  use Dir::Purge qw(purgedir_by_age);
  purgedir_by_age (5, "/spare/backups");

=head1 DESCRIPTION

Dir::Purge implements functions to reduce the number of files in a
directory according to a strategy. It currently provides one strategy:
removal of files by age.

By default, the module exports one user subroutine: C<purgedir>.

The first argument of C<purgedir> should either be an integer,
indicating the number of files to keep in each of the directories, or
a reference to a hash with options. In either case, a value for the
number of files to keep is mandatory.

The other arguments are the names of the directories that must be
purged. Note that this process is not recursive. Also, hidden files
(file name starts with a C<.>) and non-plain files (e.g., directories,
symbolic links) are not taken into account.

All directory arguments and options are checked before anything else
is done. In particular, all arguments should point to existing
directories and the program must have read, write, and search
(execute) access to the directories.

One additional function, C<purgedir_by_age>, can be exported on
demand, or called by its fully qualified name. C<purgedir_by_age>
calls C<purgedir> with the "by age" purge strategy preselected. Since
this happens to be the default strategy for C<purgedir>, calling
C<purgedir_by_age> is roughly equivalent to calling C<purgedir>.

=head1 WARNING

Removing files is a quite destructive operation. Supply the C<test>
option, described below, to dry-run before production.

=head1 OPTIONS

Options are suppled by providing a hash reference as the first
argument. The following calls are equivalent:

  purgedir ({keep => 3, test => 1}, "/spare/backups");
  purgedir_by_age ({keep => 3, test => 1}, "/spare/backups");
  purgedir ({strategy => "by_age", keep => 3, test => 1}, "/spare/backups");

All subroutines take the same arguments.

=over 4

=item keep

The number of files to keep.

If positive, the newest files will be kept. If negative, the absolute
value will be used and the oldest files will be kept.

=item strategy

Specifies the purge strategy.
Default (and only allowed) value is "by_age".

This option is for C<purgedir> only. The other subroutines should not
be provided with a C<strategy> option.

=item verbose

Verbosity of messages. Default value is 1. A value of 0 (zero) will
suppress messages.

=item debug

For internal debugging only.

=item test

If true, no files will be removed. For testing.

=back

=head1 EXPORT

Subroutine C<purgedir> is exported by default.

Subroutine C<purgedir_by_age> may be exported on demand.

Calling purgedir_by_age() is roughly equivalent to calling purgedir()
with an options hash that includes C<strategy => "by_age">.

The variable $Dir::Purge::VERSION may be used to inspect the version
of the module.

=head1 AUTHOR

Johan Vromans (jvromans@squirrel.nl) wrote this module.

=head1 COPYRIGHT AND DISCLAIMER

This program is Copyright 2000 by Squirrel Consultancy. All rights
reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of either: a) the GNU General Public License as
published by the Free Software Foundation; either version 1, or (at
your option) any later version, or b) the "Artistic License" which
comes with Perl.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See either the
GNU General Public License or the Artistic License for more details.

=cut
