#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# DEVA Filter
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "DEVA_filter" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "DEVA Filter Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv);
BEGIN {
  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "MtSQLite") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long") {
  unless (eval "use $pn; 1") {
    &_warn_add("\"$pn\" is not available on your Perl installation. ", "Please look it up on CPAN [http://search.cpan.org/]\n");
    $have_everything = 0;
  }
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Options processing

# Default values for variables
#
my $mdDBfile = "";
my $mdDBname = "metadataDB";
#
my $refDBfile = "";
my $refDBname = "referenceDB";
#
my $sysDBfile = "";
my $sysDBname = "systemDB";
#
my $tablename = "resultsTable";
my $TrialIDcolumn = "TrialID";
my $BlockIDcolumn = "BlockID";
#
my $filtercmd = "";
my $filtercmdfile = "";
my $blockIDname = $BlockIDcolumn;

my @addDBs = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:  B   F                    a    f h    m    rs  v      #

my $usage = &set_usage();

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'metadataDBfile=s'  => \$mdDBfile,
   'referenceDBfile=s' => \$refDBfile,
   'systemDBfile=s'    => \$sysDBfile,
   'filterCMD=s'       => \$filtercmd,
   'FilterCMDfile=s'   => \$filtercmdfile,
   'additionalDB=s'    => \@addDBs,
   'BlockIDname=s'     => \$blockIDname,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("No resultsDBfile information provided\n\n$usage") 
  if (scalar @ARGV != 1);

MMisc::error_quit("Both \'filterCMD\' and \'FilterCMDfile\' can not be used at the same time")
  if ((! MMisc::is_blank($filtercmd)) && (! MMisc::is_blank($filtercmdfile)));
MMisc::error_quit("One of \'filterCMD\' or \'filterCMDfile\' must be specified")
  if ((MMisc::is_blank($filtercmd)) && (MMisc::is_blank($filtercmdfile)));

if (! MMisc::is_blank($filtercmdfile)) {
  my $err = MMisc::check_file_r($filtercmdfile);
  MMisc::error_quit("Problem with \'FilterCMDfile\' file ($filtercmdfile): $err")
    if (! MMisc::is_blank($err));
}

MMisc::error_quit("The empty value is not authorized for \'BlockIDName\'")
  if (MMisc::is_blank($blockIDname));

my ($dbfile) = @ARGV;

my ($err, $sqlitecmd) = MtSQLite::get_sqlitecmd();
MMisc::error_quit($err)
  if (MMisc::is_blank($sqlitecmd));

my $cmdlines = "";
my @attachedDBs = ("temp"); # forbid use of this one already

&attach_dbfile_as($mdDBfile, $mdDBname, \$cmdlines, \@attachedDBs)
  if (! MMisc::is_blank($mdDBfile));


# Attach the REF and SYS databases
&attach_dbfile_as($refDBfile, $refDBname, \$cmdlines, \@attachedDBs);
&attach_dbfile_as($sysDBfile, $sysDBname, \$cmdlines, \@attachedDBs);

# Attach additional DBs
for (my $i = 0; $i < scalar @addDBs; $i++) {
  my $v = $addDBs[$i];
  my ($file, $name, @rest) = split(m%\:%, $v);
  MMisc::error_quit("Too many values for \'additionalDB\', expected \'file:name\' got more ($v)")
    if (scalar @rest > 0);
  MMisc::error_quit("Missing arguments for \'additionalDB\', expected \'file:name\' (got: $v)")
    if ((MMisc::is_blank($name)) || (MMisc::is_blank($file)));
  &attach_dbfile_as($file, $name, \$cmdlines, \@attachedDBs);
}

# Create the Result table
MtSQLite::commandAdd(\$cmdlines, "DROP TABLE IF EXISTS $tablename");
#MtSQLite::commandAdd(\$cmdlines, "CREATE TABLE $tablename ( $TrialIDcolumn INTEGER PRIMARY KEY )");
# was removed: we need to copy the type of the column instead of forcing it to INTEGER
MtSQLite::commandAdd(\$cmdlines, "CREATE TABLE $tablename AS SELECT $TrialIDcolumn FROM $refDBname.reference WHERE $TrialIDcolumn=\"not a value found here\"");

# Add a new column for the BlockID (string type)
MtSQLite::commandAdd(\$cmdlines, "ALTER TABLE $tablename ADD COLUMN $BlockIDcolumn STRING;");

$filtercmd = MMisc::slurp_file($filtercmdfile)
  if (! MMisc::is_blank($filtercmdfile));

MMisc::error_quit("Empty SQL command ? ($filtercmd)")
  if (MMisc::is_blank($filtercmd));

MtSQLite::commandAdd(\$cmdlines, $filtercmd);

my ($err, $log, $stdout, $stderr) = 
  MtSQLite::sqliteCommands($sqlitecmd, $dbfile, $cmdlines);
MMisc::error_quit($err) if (! MMisc::is_blank($err));

&load_stdout($stdout)
  if (! MMisc::is_blank($stdout));

&confirm_table($dbfile);

MMisc::ok_quit("Done");

####################

sub attach_dbfile_as {
  my ($dbfile, $dbname, $rcmd, $rdbl) = @_;

  my $err = MMisc::check_file_r($dbfile);
  MMisc::error_quit("Problem with \'$dbname\' DB file ($dbfile): $err")
    if (! MMisc::is_blank($err));
  my ($fname) = MtSQLite::fix_entries($dbname);
  MMisc::error_quit("Database name \$dbname\' is not properly formatted to use with SQLite (ok form: $fname)")
    if ($fname ne $dbname);
  MMisc::error_quit("Database name ($dbname) is unauthorized or already loaded")
    if (grep(m%^$dbname$%i, @$rdbl));

  MtSQLite::commandAdd($rcmd, "ATTACH DATABASE \"$dbfile\" AS $dbname;");
  push @$rdbl, $dbname;
}

##########

sub load_stdout {
  my ($so) = @_;

  my @list = split(m%[\n\r]%, $so);
  print "* Found " . scalar @list . "x rows on sqlite stdout, considering them as input to $tablename.$TrialIDcolumn (and $BlockIDcolumn) and trying to insert them\n";
  my ($err, $dbh) = MtSQLite::get_dbh($dbfile);
  MMisc::error_quit($err)
    if (! MMisc::is_blank($err));
  my $cmd = "INSERT OR ABORT INTO $tablename ( $TrialIDcolumn, $BlockIDcolumn ) VALUES ( ?, ? )";
  my ($err, $sth) = MtSQLite::get_command_sth($dbh, $cmd);
  MMisc::error_quit("Problem while inserting data into $tablename.$TrialIDcolumn: $err")
    if (! MMisc::is_blank($err));
  
  foreach my $entry (@list) {
    # only authorized splits characters are '|', ';' or ','
    my @values = split(m%[\,\|\;]%, $entry);
    push(@values, $blockIDname) if (scalar @values == 1);
    MMisc::error_quit("Found more than two values ($entry)")
      if (scalar @values > 2);
    my ($err) = MtSQLite::execute_sth($sth, @values);
    MMisc::error_quit("Problem during data insertion into $tablename.$TrialIDcolumn: $err")
      if (! MMisc::is_blank($err));
  }
  my $err = MtSQLite::sth_finish($sth);
  MMisc::error_quit("Problem while completing insertion of data into $tablename.$TrialIDcolumn: $err")
    if (! MMisc::is_blank($err));

  MtSQLite::release_dbh($dbh);
}


##########

sub confirm_table {
  my ($dbfile) = @_;
  
  my ($err, $dbh) = MtSQLite::get_dbh($dbfile);
  MMisc::error_quit($err)
    if (! MMisc::is_blank($err));

  my $cmd = "SELECT $TrialIDcolumn,$BlockIDcolumn FROM $tablename";
  my ($err, $sth) = MtSQLite::get_command_sth($dbh, $cmd);
  MMisc::error_quit("Problem confirming \'$tablename\' . \'$TrialIDcolumn\' presence: $err")
   if (! MMisc::is_blank($err));

  my $err = MtSQLite::execute_sth($sth);
  MMisc::error_quit("Problem confirming \'$tablename\' . \'$TrialIDcolumn\' presence: $err")
    if (! MMisc::is_blank($err));
  
  # Read the matching records and print them out
  my $tidc = 0;
  my $doit = 1;
  while ($doit) {
    my ($err, @data) = MtSQLite::sth_fetchrow_array($sth);
    MMisc::error_quit("Problem obtaining row: $err")
      if (! MMisc::is_blank($err));
    if (scalar @data == 0) {
      $doit = 0;
      next;
    }
    $tidc++;
  }

  my $err = MtSQLite::sth_finish($sth);
  MMisc::error_quit("Problem while completing statement: $err")
    if (! MMisc::is_blank($err));

  MMisc::error_quit("No entry in table, this DB will not be scorable")
    if ($tidc == 0);

  print "* Confirmed that Found $tablename.$TrialIDcolumn contains data (${tidc}x datum)\n";
  
  MtSQLite::release_dbh($dbh);
}

########## 

sub set_usage {  
  my $tmp=<<EOF
$versionid

$0 [--help | --version] --referenceDBfile file --systemDBfile file [--metadataDBfile file] [--additionalDB file:name [--additionalDB file:name [...]]] [--filterCMD \"SQLite COMMAND;\" | --FilterCMDfile SQLite_commands_file] [--BlockIDname name] resultsDBfile 

Will apply provided filter to databases and try to generate the results database that only contain the TrialID and BlockID that will be given to the scoring interface

NOTE: will create resultsDBfile
NOTE: if the \"BlockID\" column is not \'SELECT\'-ed as part of the filter, the literal \"$BlockIDcolumn\" will be added (unless overriden by the \"BlockIDname\" option)

Where:
  --help     This help message
  --version  Version information
  --referenceDBfile  The Reference SQLite file (loaded as '$refDBname', contains the 'Reference' table, whose columns are: TrialID, Targ)
  --systemDBfile     The System SQLite file (loaded as '$sysDBname', contains the 'System' table, whose columns are: TrialID, Decision, Score)
  --metadataDBfile   The metadata SQLite file (loaded as '$mdDBname')
  --additionalDB     Load an additional SQLite database 'file' as 'name'
  --filterCMD        Set of SQLite commands
  --FilterCMDfile    File containing set of SQLite commands
  --BlockIDname      Specify the \"$BlockIDcolumn\" value used if the column is not \'SELECT\'-ed 


EOF
;

  return($tmp);
}

