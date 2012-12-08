eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
    & eval 'exec perl -S $0 $argv:q'
    if 0;

# $Id$
# -*- perl -*-

# This is a Perl script that runs a Naming Service test.  It starts
# all the servers and clients as necessary.

use lib "$ENV{ACE_ROOT}/bin";
use PerlACE::TestTarget;
use Cwd;

$startdir = getcwd();

$quiet = 0;

# check for -q flag
if ($ARGV[0] eq '-q') {
    $quiet = 1;
}

my $test = PerlACE::TestTarget::create_target (1) || die "Create target 1 failed\n";

# Variables for command-line arguments to client and server
# executables.
$hostname = $test->HostName ();

$ns_orb_port1 = 10001 + $test->RandomPort ();
$ns_orb_port2 = 10002 + $test->RandomPort ();
$ns_endpoint1 = "iiop://$hostname:$ns_orb_port1";
$ns_endpoint2 = "iiop://$hostname:$ns_orb_port2";

$naming_persistence_dir = "NameService";

$primary_iorfile = "$naming_persistence_dir/ns_replica_primary.ior";
$combined_ns_iorfile = "combined_ns.ior";
$nm_iorfile = "nm.ior";

print STDERR "$primary_iorfile\n";

## Allow the user to determine where the persistent file will be located
## just in case the current directory is not suitable for locking.
## We can't change the name of the persistent file because that is not
## sufficient to work around locking problems for Tru64 when the current
## directory is NFS mounted from a system that does not properly support
## locking.
foreach my $possible ($ENV{TMPDIR}, $ENV{TEMP}, $ENV{TMP}) {
    if (defined $possible && -d $possible) {
      if (chdir($possible)) {
        last;
      }
    }
}

my $test_combined_ns_iorfile = $test->LocalFile ($combined_ns_iorfile);
my $test_nm_iorfile = $test->LocalFile ($nm_iorfile);
my $test_primary_iorfile = $test->LocalFile ($primary_iorfile);

$status = 0;

sub clean_persistence_dir
{
    chdir $naming_persistence_dir;
    opendir(THISDIR, ".");
    @allfiles = grep(!/^\.\.?$/, readdir(THISDIR));
    closedir(THISDIR);
    foreach $tmp (@allfiles){
        $test->DeleteFile ($tmp);
    }
    chdir "..";
}

print "INFO: Running the test in ", getcwd(), "\n";


# Make sure that the directory to use to hold the naming contexts exists
# and is cleaned out
if ( ! -d "$naming_persistence_dir" ) {
    mkdir ($naming_persistence_dir, 0777);
    }
else {
    clean_persistence_dir;
}


# Run two Naming Servers and one client.  Client uses iors
# in files to find the individual copies of the Naming Servers.

my $args = "-ORBEndPoint $ns_endpoint1 " .
           "-m 0 " .
           "-r $naming_persistence_dir " .
           "-n 100 " .
           "--primary";
my $prog = "$startdir/../../../Naming_Service/tao_ft_naming";

print STDERR "Starting Primary: $prog $args\n";

$NS1 = $test->CreateProcess ("$prog", "$args");

$test->DeleteFile ($primary_iorfile);

$NS1->Spawn ();

if ($test->WaitForFileTimed ($primary_iorfile,
                             $test->ProcessStartWaitInterval()) == -1) {
    print STDERR "ERROR: cannot find file <$test_primary_iorfile>\n";
    $NS1->Kill (); $NS1->TimedWait (1);
    exit 1;
}

$args = "-ORBEndPoint $ns_endpoint2 " .
        "-g $nm_iorfile " .
        "-c $combined_ns_iorfile " .
        "-m 0 " .
        "-n 100 " .
        "-r $naming_persistence_dir " .
        "--backup";

$prog = "$startdir/../../../Naming_Service/tao_ft_naming";

print STDERR "Starting Backup: $prog $args\n";

$NS2 = $test->CreateProcess ("$prog", "$args");

$test->DeleteFile ($combined_ns_iorfile);
$test->DeleteFile ($nm_iorfile);

$NS2->Spawn ();

if ($test->WaitForFileTimed ($combined_ns_iorfile,
                             $test->ProcessStartWaitInterval()) == -1) {
    print STDERR "ERROR: cannot find file <$test_combined_ns_iorfile>\n";
    $NS2->Kill (); $NS2->TimedWait (1);
    exit 1;
}

# Use corbaloc to access each individual name service without
# using the combined IOR.
$args = "-p corbaloc:iiop:$hostname:$ns_orb_port1/NameService " .
        "-q corbaloc:iiop:$hostname:$ns_orb_port2/NameService " .
        "-b 4 " .
        "-d 4 ";
$prog = "$startdir/client";

print STDERR "Starting Client: $prog $args\n";

$CL = $test->CreateProcess ("$prog", "$args");

$client = $CL->SpawnWaitKill ($test->ProcessStartWaitInterval());

if ($client != 0) {
    print STDERR "ERROR: client returned $client\n";
    $status = 1;
}

print STDERR "Printing Naming Tree from combined Name Service pair.\n";

$prog = "$startdir/../../../../utils/nslist/tao_nslist";
#use corbaloc
#$args = "--ns corbaloc:iiop:$hostname:$ns_orb_port1/NameService";
$args = "--ns file://$combined_ns_iorfile";

$NSL = $test->CreateProcess("$prog", "$args");
$out = $NSL->SpawnWaitKill (60);


$NS1->Kill ();
$NS2->Kill ();

$test->DeleteFile ($primary_iorfile);
$test->DeleteFile ($combined_ns_iorfile);

# Clean out the persistence dir after the test completes
#clean_persistence_dir;

exit $status;
