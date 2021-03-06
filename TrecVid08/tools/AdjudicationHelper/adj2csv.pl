#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
    if 0;

# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# TrecVid08 Adjudication files to CSV files
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Adjudication files to CSV files" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
	    || ($ENV{PERL_HASH_SEED} != 0)
	    || (! exists $ENV{PERL_PERTURB_KEYS} )
	    || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }

  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("MMisc", "ViperFramespan", "MtXML", "CSVHelper") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "TrecVid08 Adjudication files to CSV files ($versionkey)";

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

my $usage = &set_usage();
MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

# Default values for variables
my $filecheck = "";
my $roe = 1;
my $eeq = 1;
my $igw = 0;
my $igt = 0;
my $writedir = "";
my $sffnshift = "";
my $sif = "";
my $srcdir = "";
my $sknxml = 0;
my $dktrue = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:    D                         d fgh      o   s  v x   #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'filecheck=s'      => \$filecheck,
   'duplicates_warn'  => sub { $roe = 0; },
   'ensure_warn'      => sub { $eeq = 0; },
   'isGood_warn'      => \$igw,
   'IsGood_true'      => \$igt,
   'writedir=s'       => \$writedir,
   'getSFFNshift=s'   => \$sffnshift,
   'only_globalCSV'   => \$sif,
   'xmldir=s'         => \$srcdir,
   'skip_nonXML'      => \$sknxml,
   'Duplicate_keepTrue' => \$dktrue,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("Need at least 1 file arguments to work\n$usage\n") 
  if ((scalar @ARGV < 1) && (MMisc::is_blank($srcdir)));

if (! MMisc::is_blank($writedir)) {
  # Check the directory
  my ($err) = MMisc::check_dir_w($writedir);
  MMisc::error_quit("Provided \'writedir\' option directory ($writedir): $err")
    if (! MMisc::is_blank($err));
  $writedir .= "/" if ($writedir !~ m%\/$%); # Add a trailing slash
}

if (! MMisc::is_blank($sffnshift)) {
  my $err = MMisc::check_file_x($sffnshift);
  MMisc::error_quit("Problem with \'getSFFNshift\' select tool ($sffnshift): $err")
    if (! MMisc::is_blank($err));
}

##########
# Main processing

my $max_fspair = 1;

my $errstring = "ERROR STRING";

my $dummy = "dummy";

my $key_config = "config";
my $key_data = "data";
my $key_descriptor = "descriptor";
my $key_name = "name";
my $key_sourcefile = "sourcefile";
my $key_file = "file";
my $key_attr = "attribute";
my $key_osf = "ORIGSTARTFRAME";
my $key_object = "object";
my $key_fs = "framespan";
my $key_unmann = "Unmapped Annot";
my $key_loc = "location";
my $key_ds = "DetectionScore";
my $key_faf = "FromAdjFile";

my $key_agree = "Agree=";
my $key_ref = " REF";
my $key_isGood = "isGood";
my $key_id = "id";
my $key_note = "note";

my $key_annot = "Annotator";

my @fl = ();
if (MMisc::is_blank($srcdir)) {
  @fl = @ARGV;
} else {
  my $err = MMisc::check_dir_r($srcdir);
  MMisc::error_quit("Problem with XML directory ($srcdir): $err")
    if (! MMisc::is_blank($err));
  my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($srcdir);
  MMisc::error_quit("Problem with directory listing ($srcdir): $err")
    if (! MMisc::is_blank($err));
  foreach my $f (@$rf) {
    push @fl, "$srcdir/$f";
  }
}

MMisc::error_quit("No files to process ?")
  if (scalar @fl == 0);

my %all = ();
my $todo = scalar @fl;
my $done = 1;
foreach my $x (@fl) {
  print "** [$done / $todo] $x : ";

  my $err = MMisc::check_file_r($x);
  MMisc::error_quit("Problem opening file ($x): $err")
      if (! MMisc::is_blank($err));

  if ($sknxml) {
    my @cmdline = ("file", $x);
    my ($rc, $so, $se) = MMisc::do_system_call(@cmdline);
    MMisc::error_quit("Problem calling \'non xml check\' (" . join(" ", @cmdline) .")\n** Stdout: $so\n\n** Stderr: $se\n") if ($rc != 0);
    $so =~ s%^.+\:%%;
    if (! ($so =~ m%^\s*XML%)) {
      print " Skipped, Not an XML file: $so\n";
      next;
    }
  }

  my $fc = MMisc::slurp_file($x);
  MMisc::error_quit("Problem reading file ($x)")
      if (! defined $fc);

  my $esft = 0; # Value to add to each entry extracted from file
  
  my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($x);
  my $sffn = $file;
  if (! MMisc::is_blank($filecheck)) {
    if ($file =~ m%^($filecheck)%) {
      $sffn = $1;
    } else {
      MMisc::error_quit("Problem extracting file name ($file)");
    }
  } elsif (! MMisc::is_blank($sffnshift)) {
    my $cmdline = "$sffnshift $file";
    my ($rc, $so, $se) = MMisc::do_system_call($cmdline);
    MMisc::error_quit("Problem calling \'select\' ($cmdline)\n** Stdout: $so\n\n** Stderr: $se\n") if ($rc != 0);
    $so =~ s%^(\w+)%%;
    my $eok = "ok";
    my $ok = $1;
    MMisc::error_quit("Did not receive the expected \"$ok\" value (\"$ok\" instead)")
      if ($eok ne $ok);
    $so =~ s%^\s+%%;
    
    $so =~ s%^([^\s]+)%%;
    $sffn = $1;
    MMisc::error_quit("Empty file name value")
      if (MMisc::is_blank($sffn));
    $so =~ s%^\s+%%;

    $esft = MMisc::clean_begend_spaces($so);
    MMisc::error_quit("Invalid shift value ($esft)")
      if ((MMisc::is_blank($esft)) || (! MMisc::is_integer($esft)));
  }
    
  # First, extract the "Agree=" list from the <config> section
  my ($err, @acn) = &list_allconf_names(\$fc);
  MMisc::error_quit($err)
    if (! MMisc::is_blank($err));
  MMisc::error_quit("No entry in All Conf Names")
      if (scalar @acn == 0);
  my @agl = grep(m%^$key_agree%, @acn);
  MMisc::error_quit("No entry in Agree List")
      if (scalar @acn == 0);
  my @evt = grep(m%$key_ref$%, @acn);
  MMisc::error_quit("No entry in Event list")
      if (scalar @evt == 0);
  MMisc::error_quit("More than one entry in Event list")
      if (scalar @evt > 1);
  my $event = $evt[0];
  $event =~ s%$key_ref$%%;

  # Fill %all
  my $err = &fill_all(\$fc, $sffn, $event, $x, $esft, @agl);
  MMisc::error_quit($err)
    if (! MMisc::is_blank($err));
  
  print "done\n";
  $done++;
}

my $ch = new CSVHelper();
MMisc::error_quit("Problem creating the CSV object: " . $ch->get_errormsg())
  if ($ch->error());

my $gch = new CSVHelper();
MMisc::error_quit("Problem creating the CSV object: " . $gch->get_errormsg())
  if ($gch->error());

my $global = "${writedir}global.csv";
my $global_txt = "";
my @gh = ("File", "Event", "AgreeLevel", "MeanDetectionScore", "Framespan", "isGood", "FromADJFile", "NbrAnnot", "AnnotList", "Note");
$global_txt .= &array2csvline($gch, @gh);
$gch->set_number_of_columns(scalar @gh);

my @a = ("EventType", "Framespan");
$ch->set_number_of_columns(scalar @a);

foreach my $sffn (sort keys %all) {
  my $file = "$writedir$sffn.csv";
  my $file_txt = "";
  $file_txt .= &array2csvline($ch, @a);
  foreach my $event (sort keys %{$all{$sffn}}) {
    foreach my $agl (sort keys %{$all{$sffn}{$event}}) {
      my @l = keys %{$all{$sffn}{$event}{$agl}};
      foreach my $fs (sort _fs_sort @l) {
        my @anl  = @{$all{$sffn}{$event}{$agl}{$fs}{$key_annot}};
        my $isg  = $all{$sffn}{$event}{$agl}{$fs}{$key_isGood};
        my $id   = $all{$sffn}{$event}{$agl}{$fs}{$key_id};
        my $note = $all{$sffn}{$event}{$agl}{$fs}{$key_note};
        my $mds  = $all{$sffn}{$event}{$agl}{$fs}{$key_ds};
        my $faf  = $all{$sffn}{$event}{$agl}{$fs}{$key_faf};

        my $sagl = -1;
        my $sagl = $1 if ($agl =~ m%\=(\d+)$%);
        MMisc::error_quit("Could not extract agree level ($agl)")
          if ($sagl == -1);

        if ($isg) {
          my @b = ($event, $fs);
          $file_txt .= &array2csvline($ch, @b);
        }

        my @c = ($sffn, $event, $sagl, $mds, $fs, $isg, $faf, scalar @anl, join(" ", sort @anl), $note);
        $global_txt .= &array2csvline($gch, @c);
      }
    }
  }
  MMisc::writeTo($file, "", 1, 0, $file_txt) if (! $sif);
}
MMisc::writeTo($global, "", 1, 0, $global_txt);

#print MMisc::get_sorted_MemDump(\%all);

MMisc::ok_quit("Done\n");

########## END

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

##########

sub list_allconf_names {
  my $rfc = shift @_;

  my $config = MtXML::get_named_xml_section("config", $rfc, $errstring);
  return("Problem extracting \'config\' section", ())
    if ($config eq $errstring);
  
  my $doit = 1;
  my @list = ();
  while ($doit) {
    my $tmp = MtXML::get_named_xml_section($key_descriptor, \$config, $errstring);
    if ($tmp eq $errstring) {
      $doit = 0;
      next;
    }
    my ($err, %tmph) = MtXML::get_inline_xml_attributes($key_descriptor, $tmp);
    retutn("Could not extract \'$key_descriptor\' \'s \'$key_name\' inline attribute", ())
      if (! exists $tmph{$key_name});
    push @list, $tmph{$key_name};
  }

  return("", @list);
}

#####

sub fill_all {
  my ($rfc, $sffn, $event, $fn, $esft, @agl) = @_;

  my %local = ();

  # Extract the data section
  my $data = MtXML::get_named_xml_section($key_data, $rfc, $errstring);
  return("Problem extracting \'$key_data\' section")
    if ($data eq $errstring);

  # Now the sourcefile section: get Origstartframe
  my ($err, $osf) = &extract_orig_start_frame(\$data);
  return($err)
    if ($err eq $errstring);
  return("\'$key_osf\' can not be < 1")
    if ($osf < 1);

  my %tofind = ();
  foreach my $key (@agl) { $tofind{$key}++; }

  ## Then the objects themselves
  
  # first, the Agree List
  foreach my $key (@agl) {
    my $doit = 1;
    while ($doit) {
      my ($err, $framespan, $id, $isGood, $note, $notin, $mds) 
        = &get_agree($key, \$data);
      return($err) 
        if (! MMisc::is_blank($err));
      $data .= $notin;
      if (! defined $framespan) {
        return("Could not find at least one \'$key\'")
          if (exists $tofind{$key});
        $doit = 0;
        next;
      }

      ($err, $framespan) = &fix_fs($framespan, $osf + $esft);
      return($err) if (! MMisc::is_blank($err));

      delete($tofind{$key})
        if (exists $tofind{$key});
      return("An entry already exists for [$key | $id ]")
        if (exists $local{$key}{$id}{$dummy});
      my ($disc, $agv) = split(m%\=%, $key);
      $local{$key}{$id}{$dummy}      = $agv;
      $local{$key}{$id}{$key_fs}     = $framespan;
      @{$local{$key}{$id}{$key_annot}}  = ();
      $local{$key}{$id}{$key_isGood} = $isGood;
      $local{$key}{$id}{$key_note}   = $note;
      $local{$key}{$id}{$key_ds}     = $mds;
#      print "[$sffn | $event | $key | $id | $framespan | $isGood | $note] ";
    }
  }

  # Then add the annotator information to the list
  my $doit = 1;
  while ($doit) {
    my ($err, $framespan, $id, $location, $notin) 
      = &get_unmann(\$data);
    return($err) 
      if (! MMisc::is_blank($err));
    $data .= $notin;
    if (! defined $framespan) {
      $doit = 0;
      next;
    }

    ($err, $framespan) = &fix_fs($framespan, $osf + $esft);
    return($err)
      if (! MMisc::is_blank($err));

    my ($agk, $idk, @ans) = split(m%\s+%, $location);
    $idk =~ s%^.+\=%%;

    return("WEIRD: Multiple Annotators found in location list ? (" . join(" ", @ans) . ")")
      if (scalar @ans > 1);

    return("An entry for [$agk | $idk] does not already exist as expected ?")
      if (! exists $local{$agk}{$idk}{$dummy});
    my $idt = $ans[0] . "($id|$framespan)";
    push @{$local{$agk}{$idk}{$key_annot}}, $idt;
#    print "%[$sffn | $event | $key_unmann | $id | $framespan | [$agk | $idk | ", join(" ", @ans), "] ] ";
  }

  # Now check that the count for each 'Agree=' has the proper number of elements
  foreach my $key1 (keys %local) {
    foreach my $key2 (keys %{$local{$key1}}) {
      my $exp = $local{$key1}{$key2}{$dummy};
      my $in  = scalar @{$local{$key1}{$key2}{$key_annot}};
      if ($exp != $in) {
        my $txt = "Did not find the same number of entries for ($key1 / $key2): exp $exp vs found $in [$fn]";
        return($txt)
          if ($eeq);
        print "########## $txt ##########\n";
      }
    }
  }

  # Finally convert the local list into the global list
  foreach my $agk (keys %local) {
    foreach my $idk (keys %{$local{$agk}}) {
      my $fs = $local{$agk}{$idk}{$key_fs};
      if (exists $all{$sffn}{$event}{$agk}{$fs}{$key_annot}) {
        my $og = $all{$sffn}{$event}{$agk}{$fs}{$key_isGood};
        my $ng = $local{$agk}{$idk}{$key_isGood};
        my $od = $all{$sffn}{$event}{$agk}{$fs}{$key_ds};
        my $nd = $local{$agk}{$idk}{$key_ds};
        my $of = $all{$sffn}{$event}{$agk}{$fs}{$key_faf};
        my $oi = $all{$sffn}{$event}{$agk}{$fs}{$key_id};
        my $txt = "An entry already exists for [$sffn | $event | $agk | $fs] -- Old: [isGood: $og | DetScr: $od | ID: $oi | AdjFile: $of] vs New: [isGood: $ng | DetScr: $nd | ID: $idk | AdjFile: $fn]";
        $txt .= " (**isGood Differ**)" if ($ng != $og);
        $txt .= " (**DetScr Differ**)" if ($od != $ng);
        $txt .= " (**AdjFile Differ**)" if ($of ne $fn);

        return($txt) if ($roe);

        if (! $dktrue) {
          print "########## $txt (skipping entry) ##########\n";
          next;
        }
        
        if (! $ng) {
          print "@@@@@@@@@@ $txt (New entry \'isGood\' false => skipping entry) @@@@@@@@@@\n";
          next;
        }

        print "%%%%%%%%%% $txt (New entry \'isGood\' true => replacing entry) %%%%%%%%%%\n";
      }
      
      @{$all{$sffn}{$event}{$agk}{$fs}{$key_annot}} =
        @{$local{$agk}{$idk}{$key_annot}};
      $all{$sffn}{$event}{$agk}{$fs}{$key_isGood} = 
        $local{$agk}{$idk}{$key_isGood};
      $all{$sffn}{$event}{$agk}{$fs}{$key_note} = 
        $local{$agk}{$idk}{$key_note};
      $all{$sffn}{$event}{$agk}{$fs}{$key_id} = 
        $idk;
      $all{$sffn}{$event}{$agk}{$fs}{$key_ds} = 
        $local{$agk}{$idk}{$key_ds};
      $all{$sffn}{$event}{$agk}{$fs}{$key_faf} = 
        $fn;
    }
  }

  return("");
}

#####

sub _extract_attrhash {
  my $str = shift @_;

  my %attrh = ();
  while (! MMisc::is_blank($str)) {
    my $name = MtXML::get_next_xml_name(\$str, $errstring);
    return("Problem obtaining a valid XML name, aborting", ())
      if ($name eq $errstring);
    return("Extraction process does not seem to have found one, aborting", ())
      if ($name !~ m%^$key_data\:%i);
    my $section = MtXML::get_named_xml_section($name, \$str, $errstring);
    return("Problem obtaining the \'data\:\' XML section, aborting", ())
      if ($name eq $errstring);

    # All within a data: entry is inlined, so get the inlined content
    my ($text, %iattr) = MtXML::get_inline_xml_attributes($name, $section);
    return($text, ()) if (! MMisc::is_blank($text));

    # From here we work per 'data:' type
    $name =~ s%^data\:%%;

    $attrh{$name} = \%iattr;
  }

  return("", %attrh);
}

#####

sub extract_orig_start_frame {
  my $rds = shift @_;

  my $sf = MtXML::get_named_xml_section($key_sourcefile, $rds, $errstring);
  return("Problem extracting \'$key_data\' section", 0)
    if ($sf eq $errstring);


  my $tmp = MtXML::get_named_xml_section($key_file, \$sf, $errstring);
  return("Problem extracting \'$key_file\' section", 0)
    if ($tmp eq $errstring);

  my $doit = 1;
  my $osf = 0;
  while ($doit) {
    my $tmp2 = MtXML::get_named_xml_section($key_attr, \$tmp, $errstring);
    if ($tmp2 eq $errstring) {
      $doit = 0;
      next;
    }

    my ($err, %tmph) = MtXML::get_inline_xml_attributes($key_attr, $tmp2);
    return($err)
      if (! MMisc::is_blank($err));
    return("Could not extract \'$key_attr\' \'s \'$key_name\' inline attribute", 0)
      if (! exists $tmph{$key_name});

    if ($tmph{$key_name} eq $key_osf) {
      return("WEIRD: could not remove the \'$key_attr\' header and trailer tags", 0)
        if (! MtXML::remove_xml_tags($key_attr, \$tmp2));
      
      my ($err, %iattr) = &_extract_attrhash($tmp2);
      return($err, 0)
        if (! MMisc::is_blank($err));
      my ($err, $tosf) = MMisc::dive_structure(\%iattr);
      return($err, 0)
        if (! MMisc::is_blank($err));
      $osf = $tosf;
      $doit = 0;
      next;
    }
  }
  return("Could not find \'$key_osf\'", 0)
    if ($osf == 0);

  return("WEIRD: could not remove the \'$key_sourcefile\' header and trailer tags", 0)
        if (! MtXML::remove_xml_tags($key_sourcefile, \$sf));
  $$rds = $sf;

  return("", $osf);
}

##########

sub _get_isgnote {
  my ($txt) = @_;

  my $ig = -1;
  my $nt = "";

  my $doit = 1;
  while ($doit) {
    my $tmp2 = MtXML::get_named_xml_section($key_attr, \$txt, $errstring);
    if ($tmp2 eq $errstring) {
      $doit = 0;
      next;
    }

    my ($err, %tmph) = MtXML::get_inline_xml_attributes($key_attr, $tmp2);
    return($err)
      if (! MMisc::is_blank($err));
    return("Could not extract \'$key_attr\' \'s \'$key_name\' inline attribute", 0)
      if (! exists $tmph{$key_name});

    return("WEIRD: could not remove the \'$key_attr\' header and trailer tags", 0)
      if (! MtXML::remove_xml_tags($key_attr, \$tmp2));

    next if (MMisc::is_blank($tmp2));

    my ($err, %iattr) = &_extract_attrhash($tmp2);
    return($err, $ig, $nt)
      if (! MMisc::is_blank($err));
    my ($err, $tv) = MMisc::dive_structure(\%iattr);
    return($err, $ig, $nt)
      if (! MMisc::is_blank($err));

    if ($tmph{$key_name} eq $key_isGood) {
      $ig = $tv;
    } else {
      $nt = $tv;
    }
  }

  if ($ig == -1) {
    return("Did not find \'$key_isGood\'", $ig, $nt)
      if (! $igw);
    
    print "########## Did not find a value for \'$key_isGood\', forcing to " . (($igt) ? "true" : "false") . " ##########\n";
    $ig = $igt;
  }
  
  $ig = 1 if ($ig eq "true");
  $ig = 0 if ($ig eq "false");

  return("Unknow \'$key_isGood\' value ($ig)", $ig, $nt)
    if (($ig != 0) && ($ig != 1));

  return("", $ig, $nt);
}

#####

sub get_agree {
  my ($key, $rtxt) = @_;

  my $notin = "";
  
  my $doit = 1;
  my $fs = undef;
  my $id = -1;
  my $ig = -1; # isGood
  my $nt = ""; # Note
  my $ds = "NotPresent";
  while ($doit) {
    my $tmp = MtXML::get_named_xml_section($key_object, $rtxt, $errstring);
    return("", $fs, $id, $ig, $nt, $notin, $ds)
      if ($tmp eq $errstring); # No more
    
    my ($err, %tmph) = MtXML::get_inline_xml_attributes($key_object, $tmp);
    return($err, $fs, $id, $ig, $nt, $notin, $ds)
      if (! MMisc::is_blank($err));
    return("Could not extract \'$key_object\'\'s \'$key_name\' inline attribute", $fs, $id, $ig, $nt, $notin, $ds)
      if (! exists $tmph{$key_name});
    
    if ($tmph{$key_name} ne $key) {
      $notin .= "$tmp\n";
      next;
    }
    
    return("Could not extract \'$key_object\'\'s \'$key_fs\' inline attribute", $fs, $id, $ig, $nt, $notin, $ds)
      if (! exists $tmph{$key_fs});
    return("Could not extract \'$key_object\'\'s \'$key_id\' inline attribute", $fs, $id, $ig, $nt, $notin, $ds)
      if (! exists $tmph{$key_id});
    $fs = $tmph{$key_fs};
    $id = $tmph{$key_id};
    $ds = $tmph{$key_ds}
      if (exists $tmph{$key_ds});
    
    ($err, $ig, $nt) = _get_isgnote($tmp);
    return($err, $fs, $id, $ig, $nt, $notin, $ds)
      if (! MMisc::is_blank($err));
    
    $doit = 0;
  }

  return("", $fs, $id, $ig, $nt, $notin, $ds);
}

##########

sub _get_lc {
  my ($txt) = @_;

  my $lc = "";

  my $tmp2 = MtXML::get_named_xml_section($key_attr, \$txt, $errstring);
  return("Could not find \'$key_attr\'", $lc)
    if ($tmp2 eq $errstring);

  my ($err, %tmph) = MtXML::get_inline_xml_attributes($key_attr, $tmp2);
  return($err, $lc)
    if (! MMisc::is_blank($err));
  return("Could not extract \'$key_attr\' \'s \'$key_name\' inline attribute", $lc)
    if (! exists $tmph{$key_name});

  return("Did not find \'$key_loc\' attribute")
    if ($tmph{$key_name} ne $key_loc);

  return("WEIRD: could not remove the \'$key_attr\' header and trailer tags", $lc)
    if (! MtXML::remove_xml_tags($key_attr, \$tmp2));

  return("\'$key_loc\' has no value ?", $lc)
    if (MMisc::is_blank($tmp2));

  my ($err, %iattr) = &_extract_attrhash($tmp2);
  return($err, $lc)
    if (! MMisc::is_blank($err));
  ($err, $lc) = MMisc::dive_structure(\%iattr);
  return($err, $lc)
    if (! MMisc::is_blank($err));

  return("Empty \'$key_loc\'", $lc)
    if (MMisc::is_blank($lc));

  return("", $lc);
}

#####

sub get_unmann {
  my ($rtxt) = @_;

  my $notin = "";

  my $doit = 1;
  my $fs = undef;
  my $id = -1;
  my $lc = "";
  while ($doit) {
    my $tmp = MtXML::get_named_xml_section($key_object, $rtxt, $errstring);
    return("", $fs, $id, $lc, $notin)
      if ($tmp eq $errstring); # No more

    my ($err, %tmph) = MtXML::get_inline_xml_attributes($key_object, $tmp);
    return($err, $fs, $id, $lc, $notin)
      if (! MMisc::is_blank($err));
    return("Could not extract \'$key_object\'\'s \'$key_name\' inline attribute", $fs, $id, $lc, $notin)
      if (! exists $tmph{$key_name});

    if ($tmph{$key_name} ne $key_unmann) {
      $notin .= "$tmp\n";
      next;
    }

    return("Could not extract \'$key_object\'\'s \'$key_fs\' inline attribute", $fs, $id, $lc, $notin)
      if (! exists $tmph{$key_fs});
    return("Could not extract \'$key_object\'\'s \'$key_id\' inline attribute", $fs, $id, $lc, $notin)
      if (! exists $tmph{$key_id});
    $fs = $tmph{$key_fs};
    $id = $tmph{$key_id};

    ($err, $lc) = _get_lc($tmp);
    return($err, $fs, $id, $lc, $notin)
      if (! MMisc::is_blank($err));

    $doit = 0;
  }

  return("", $fs, $id, $lc, $notin);
}

##########

sub fix_fs {
  my ($fs, $osf) = @_;

  my $fs_fs = new ViperFramespan($fs);
  return($fs_fs->get_errormsg(), -1)
    if ($fs_fs->error());

  my $count = $fs_fs->count_pairs_in_value();
  return($fs_fs->get_errormsg(), -1)
    if ($fs_fs->error());
  return("Found more than the maximum authorized range pair in framespan (authorized: $max_fspair) (found: $count) [fs: $fs]")
    if ($count > $max_fspair);

  $fs_fs->value_shift($osf);
  return($fs_fs->get_errormsg(), -1)
    if ($fs_fs->error());

  my $v = $fs_fs->get_value();
  return($fs_fs->get_errormsg(), -1)
    if ($fs_fs->error());

  return("", $v);
}

##########

sub _fs_sort {
  my ($b1, $e1) = split(m%\:%, $a);
  my ($b2, $e2) = split(m%\:%, $b);

  # Order by beginning first
  return($b1 <=> $b2) if ($b1 != $b2);
  # by end if the beginning is the same
  return($e1 <=> $e2);
}

##########

sub array2csvline {
  my ($ch, @array) = @_;

  my $tmp = $ch->array2csvline(@array);

  MMisc::error_quit("Problem adding entries to CSV file: " . $ch->get_errormsg())
    if ($ch->error());

  return("$tmp\n");
}

############################################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [options] file(s).xml 

Will generate the global.csv and sffn.csv files needed to reinject adjudicated files into XML files

 Where:
  --help              Print this usage information and exit
  --version           Print version number and exit
  --filecheck regexp  Regular expression used to extract the file structure from source filename (example: \'LGW_\\d{8}_E\\d_CAM\\d\')
  --duplicates_warn   When finding duplicate keys, do not exit with error status, simply discard found duplicates
  --Duplicate_keepTrue  When finding duplicate keys, do not discard isGood=true entry, replace isGood=false ones
  --ensure_warn       When finding a problem with Agree counts, do not exit with error status, simply print a warning message
  --isGood_warn       When finding a problem with isGood content, do not exit, print a warning and set the isGood value to false
  --IsGood_true       extension to --isGood_warn; instead of setting value to false, set it to true
  --writedir dir      Specify the output directory
  --getSFFNshift program      Program called to extract SFFN and shift from adjudicated filename (expected to return three parameters: ok SFFN shiftvalue)
  --only_globalCSV    Only generate the "global.csv" file
  --xmldir dir        Specify a directory to be listed for all XML files to be processed
  --skip_nonXML       Check that the file is truly XML before trying to load it
EOF
    ;

    return $tmp;
}
