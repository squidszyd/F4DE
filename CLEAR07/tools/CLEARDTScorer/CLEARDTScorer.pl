#!/usr/bin/env perl

# CLEAR Detection and Tracking Scorer
#
# Author(s): Vasant Manohar
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEAR Detection and Tracking Scorer" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
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

my $versionid = "CLEAR Detection and Tracking Scorer Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($dateb, $datebv, $clearpl, $clearplv, $datepl, $dateplv);
BEGIN {
  $dateb = "DATE_BASE";
  $datebv = $ENV{$dateb} . "/lib";
  $clearpl = "CLEAR_PERL_LIB";
  $clearplv = $ENV{$clearpl} || "../../lib"; # Default is relative to this tool's default path
  $datepl = "DATE_PERL_LIB";
  $dateplv = $ENV{$datepl} || "../../../common/lib";  # Default is relative to this tool's default path
}
use lib ($clearplv, $dateplv, $datebv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $dateb environment variable (if you did an install, otherwise your $clearpl and $datepl environment variables).";

# CLEARDTViperFile (part of this tool)
unless (eval "use CLEARDTViperFile; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"CLEARDTViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# CLEARDTHelperFunctions (part of this tool)
unless (eval "use CLEARDTHelperFunctions; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"CLEARDTHelperFunctions\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Sequence (part of this tool)
unless (eval "use Sequence; 1")
  {
    my $pe = &eo2pe($@);
    warn_print("\"Sequence\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }

# SimpleAutoTable (part of this tool)
unless (eval "use SimpleAutoTable; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"SimpleAutoTable\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1")
  {
    warn_print
      (
       "\"Getopt::Long\" is not available on your Perl installation. ",
       "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
      );
    $have_everything = 0;
  }

# Data::Dumper (usually part of the Perl Core)
unless (eval "use Data::Dumper; 1")
   {
    warn_print
      (
       "\"Data::Dumper\" is not available on your Perl installation. ",
       "Please visit \"http://search.cpan.org/~rgarcia/perl-5.10.0/lib/File/Basename.pm\" for installation information\n"
      );
    $have_everything = 0;
  }   

# Something missing ? Abort
MMisc::error_quit("Some Perl Modules are missing, aborting\n") unless $have_everything;

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Get some values from CLEARDTViperFile
my $dummy = new CLEARDTViperFile();
my @ok_objects = $dummy->get_full_objects_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

########################################
# Options processing

my $xmllint_env = "CLEAR_XMLLINT";
my $xsdpath_env = "CLEAR_XSDPATH";
my $usage = &set_usage();

# Default values for variables
my $gtfs = 0;
my $xmllint = &_get_env_val($xmllint_env, "");
my $xsdpath = &_get_env_val($xsdpath_env, "../../data");
$xsdpath = "$datebv/data" 
  if (($datebv ne "/lib") && ($xsdpath eq "../../data"));
my $xmlbasefile = -1;
my $evaldomain  = undef;
my $eval_type   = undef;
my $det_thres   = 1.0;
my $trk_thres   = 1.0;
my $CostMiss    = 1.0;
my $CostFA      = 1.0;
my $CostIS      = 1.0;
my $bin         = 0;
my $frameTol    = 0;
my $writeback   = -1;

my %opt;
my $dbgftmp = "";

my $commandline = $0 . join(" ", @ARGV) . "\n\n";
my @leftover;
GetOptions
  (
   \%opt,
   'help',
   'version',
   "XMLbase:s"       => \$xmlbasefile,
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'Domain:s'        => \$evaldomain,
   'Eval:s'          => \$eval_type,
   'detthres=f'      => \$det_thres,
   'trkthres=f'      => \$trk_thres,
   'MissCost=f'      => \$CostMiss,
   'FACost=f'        => \$CostFA,
   'ISCost=f'        => \$CostIS,
   'bin'             => \$bin,
   'frameTol=i'      => \$frameTol,
   'write:s'         => \$writeback,   
   'gtf'             => sub {$gtfs++; @leftover = @ARGV},
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

if (defined $evaldomain) { 
  $evaldomain = uc($evaldomain);
  MMisc::error_quit("Unknown 'Domain'. Has to be (BN, MR, SV, UV), aborting\n\n$usage\n") if ( ($evaldomain ne "BN") && ($evaldomain ne "MR") && ($evaldomain ne "SV") && ($evaldomain ne "UV") );
  $dummy->set_required_hashes($evaldomain); 
}
else { MMisc::error_quit("'Domain' is a required argument (BN, MR, SV, UV), aborting\n\n$usage\n"); }

if (defined $eval_type) {
  if (lc($eval_type) eq "area") { $eval_type = "Area"; }
  elsif (lc($eval_type) eq "point") { $eval_type = "Point";}
  else { MMisc::error_quit("Unknown 'EvalType'. Has to be (area, point), aborting\n\n$usage\n"); }
}
else { MMisc::error_quit("'EvalType' is a required argument (area, point), aborting\n\n$usage\n"); }

if ($xmlbasefile != -1) {
  my $txt = $dummy->get_base_xml(@ok_objects);
  MMisc::error_quit("While trying to obtain the base XML file (" . $dummy->get_errormsg() . ")")
    if ($dummy->error());

  MMisc::writeTo($xmlbasefile, "", 0, 0, $txt);  

  MMisc::ok_quit($txt);
}

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'CLEARxsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

if (($writeback != -1) && ($writeback ne "")) {
  # Check the directory
  MMisc::error_quit("Provided \'write\' option directory ($writeback) does not exist")
    if (! -e $writeback);
  MMisc::error_quit("Provided \'write\' option ($writeback) is not a directory")
    if (! -d $writeback);
  MMisc::error_quit("Provided \'write\' option directory ($writeback) is not writable")
    if (! -w $writeback);
  $writeback .= "/" if ($writeback !~ m%\/$%); # Add a trailing slash
}

MMisc::error_quit("Only one \'gtf\' separator allowed per command line, aborting")
  if ($gtfs > 1);

my ($rref, $rsys) = &get_sys_ref_filelist(\@leftover, @ARGV);
my @ref = @{$rref};
my @sys = @{$rsys};
MMisc::error_quit("No SYS file(s) provided, can not perform scoring")
  if (scalar @sys == 0);
MMisc::error_quit("No REF file(s) provided, can not perform scoring")
  if (scalar @ref == 0);
MMisc::error_quit("Unequal number of REF and SYS files, can not perform scoring")
  if (scalar @ref != scalar @sys);

##########
# Main processing
my $ntodo = scalar @ref;

my $results = new SimpleAutoTable();
MMisc::error_quit("Error final results table: ".$results->get_errormsg()."\n")
   if (! $results->setProperties({ "SortRowKeyTxt" => "Alpha", "KeyColumnTxt" => "Remove" }));

my (@ref_seqs, @sys_seqs);

for (my $loop = 0; $loop < $ntodo; $loop++) {
  my ($ref_ok, $gtSequence) = &load_file(1, $ref[$loop]);
  MMisc::error_quit("Could not load ground truth scoring sequence: $ref[$loop]\n") if (! $ref_ok);
  # print(Dumper(\$gtSequence));
  my %ref_seq = ( 'sequence'    => $gtSequence,
                  'filename'    => $gtSequence->getSeqFileName(),
                  'video_file'  => $gtSequence->getSourceFileName(),
                  'beg_fr'      => $gtSequence->getSeqBegFr(),
                  'end_fr'      => $gtSequence->getSeqEndFr(),
                );
  push @ref_seqs, \%ref_seq;

  my ($sys_ok, $sysSequence) = &load_file(0, $sys[$loop]);
  MMisc::error_quit("Could not load system output scoring seqeunce: $sys[$loop]\n") if (! $sys_ok);
  my %sys_seq = ( 'sequence'    => $sysSequence,
                  'filename'    => $sysSequence->getSeqFileName(),
                  'video_file'  => $sysSequence->getSourceFileName(),
                  'beg_fr'      => $sysSequence->getSeqBegFr(),
                  'end_fr'      => $sysSequence->getSeqEndFr(),
                );
  push @sys_seqs, \%sys_seq;
}

# Prepare for batch processing
my @files_to_be_processed;
foreach my $ref_file (@ref_seqs) {
    my $checkFlag = 0; # To check if we matched a reference file
    my ($ref_video_filename, $ref_start_frame, $ref_end_frame) = ($ref_file->{'video_file'}, $ref_file->{'beg_fr'}, $ref_file->{'end_fr'});
    foreach my $sys_file (@sys_seqs) {
        my ($sys_video_filename, $sys_start_frame, $sys_end_frame) = ($sys_file->{'video_file'}, $sys_file->{'beg_fr'}, $sys_file->{'end_fr'});
        # Systems can report outside of the evaluation framespan
        if (($ref_video_filename eq $sys_video_filename) && ($sys_start_frame <= $ref_start_frame) && ($sys_end_frame >= $ref_end_frame)) {
            push @files_to_be_processed, [$ref_file->{'sequence'}, $sys_file->{'sequence'}];
            $checkFlag = 1;
            last;
        }
    }
    print "Could not find matching system output file for " . $ref_file->{'filename'} . ". Skipping file\n" if (! $checkFlag);
}

# Start processing
my $ndone = 0;
my ($gtSequence, $sysSequence, $ref_eval_obj, $sys_eval_obj);
foreach my $ref_sys_pair (@files_to_be_processed){
  my ($sfda, $ata, $moda, $modp, $mota, $motp);
  $gtSequence = $ref_sys_pair->[0];
  $sysSequence = $ref_sys_pair->[1];

  $ref_eval_obj = $gtSequence->getEvalObj();
  $sys_eval_obj = $sysSequence->getEvalObj();

  if (MMisc::is_blank($ref_eval_obj) && MMisc::is_blank($sys_eval_obj)) { 
    &add_data2sat($results, $ndone+1, $gtSequence->getSeqFileName, $sysSequence->getSeqFileName, $gtSequence->getSourceFileName, $ref_eval_obj, $eval_type, $sfda, $ata, $moda, $modp, $mota, $motp);
    $ndone++;
    next;
  }
  elsif (MMisc::is_blank($ref_eval_obj)) { $ref_eval_obj = $sys_eval_obj; }
  elsif ($ref_eval_obj ne $sys_eval_obj) { MMisc::error_quit("Not possible to evaluate two different evaluation objects. Ground truth object: $ref_eval_obj\t System output object: $sys_eval_obj\n"); }

  $sfda = $gtSequence->computeSFDA($sysSequence, $eval_type, $det_thres, $bin);
  MMisc::error_quit("Error computing 'SFDA' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());
  $ata = $gtSequence->computeATA($sysSequence, $eval_type, $trk_thres, $bin);
  MMisc::error_quit("Error computing 'ATA' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());

  $moda = $gtSequence->computeMODA($sysSequence, $CostMiss, $CostFA, $eval_type, $det_thres, $bin);
  MMisc::error_quit("Error computing 'MODA' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());
  $modp = $gtSequence->computeMODP($sysSequence, $eval_type, $det_thres, $bin);
  MMisc::error_quit("Error computing 'MODP' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());

  $mota = $gtSequence->computeMOTA($sysSequence, $CostMiss, $CostFA, $CostIS, $eval_type, $trk_thres, $bin);
  MMisc::error_quit("Error computing 'MOTA' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());
  $motp = $gtSequence->computeMOTP($sysSequence, $eval_type, $trk_thres, $bin);
  MMisc::error_quit("Error computing 'MOTP' (" . $gtSequence->get_errormsg() . ")")
      if ($gtSequence->error());

  &add_data2sat($results, $ndone+1, $gtSequence->getSeqFileName, $sysSequence->getSeqFileName, $gtSequence->getSourceFileName, $ref_eval_obj, $eval_type, $sfda, $ata, $moda, $modp, $mota, $motp);

  $ndone++;
}

my $tbl = $results->renderTxtTable(2);
MMisc::error_quit("ERROR: Generating Final Report (". $results->get_errormsg() . ")") if (! defined($tbl));

my $param_setting = &get_param_settings();

my $output = $commandline . $param_setting . $tbl;
my $fname = "";
if (($writeback != -1) && ($writeback ne "")) {
    my @sysfields = split(/[_-]/, $files_to_be_processed[0]->[1]->getSeqFileName()); # Get one system filename
    my $tmp = $sysfields[0] . "_" . $evaldomain . "_" . $ref_eval_obj . "_DT.res";
    $fname = "$writeback$tmp";
} 
MMisc::error_quit("Problem while trying to \'write\'")
  if (! MMisc::writeTo($fname, "", 1, 0, $output, "", "** Detection and Tracking Results:\n"));

MMisc::ok_quit("\n\n***** DONE *****\n");

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;
  foreach (split(/\n/, $txt)){ 
    &valok($fname, "[ERROR] $_");
  }
}

##########

sub load_file {
  my ($isgtf, $tmp) = @_;

  my ($retstatus, $object, $msg) = 
    CLEARDTHelperFunctions::load_ScoringSequence($isgtf, $tmp, $evaldomain, $frameTol, $xmllint, $xsdpath);

  if (! $retstatus) {
    &valerr($tmp, $msg);
  }

  return($retstatus, $object);
}

########################################

sub set_usage {
  my $ro = join(" ", @ok_objects);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--XMLbase [file]] [--xmllint location] [--CLEARxsd location] --Domain name --Eval type [--write [directory]] [--detthres value] [--trkthres value] [--bin] [--MissCost value] [--FACost value] [--ISCost value] sys_file.xml [sys_file.xml [...]] --gtf ref_file.xml [ref_file.xml [...]]

Will Score the XML file(s) provided (Reference vs System)

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --XMLbase       Print a Viper file with an empty <data> section and a populated <config> section, and exit (to a file if one provided on the command line)
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd      Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --Domain        Specify the evaluation domain for the set of files (BN, MR, SV, UV)
  --Eval          Specify the type of measures that you want to compute (Area, Point)
  --detthres      Set the threshold for spatial overlap between reference and system objects when computing detection measures (default: $det_thres)
  --trkthres      Set the threshold for spatial overlap between reference and system objects when computing tracking measures (default: $trk_thres)
  --bin           Specify if the thresholding should be 'binary' ( >= thres = 1.0, < thres = 0.0) or 'regular' ( >=thres = 1.0, < thres = actual overlap ratio) (default: 'regular')
  --MissCost      Set the Metric's Cost for a Miss (default: $CostMiss)
  --FACost        Set the Metric's Cost for a False Alarm (default: $CostFA)
  --ISCost        Set the Metric's Cost for an ID Switch (default: $CostIS)
  --gtf           Specify that the files post this marker on the command line are Ground Truth Files  

Note:
- Program will ignore the <config> section of the XML file.
- List of recognized objects: $ro
- 'CLEARxsd' files are: $xsdfiles
EOF
;

  return $tmp;
}

########################################

sub warn_print {
  print "WARNING: ", @_;

  print "\n";
}

########################################

sub _get_env_val {
  my $envv = shift @_;
  my $default = shift @_;

  my $var = $default;

  $var = $ENV{$envv} if (exists $ENV{$envv});

  return($var);
}

########################################

sub get_param_settings {
  my $str;

  if ($eval_type eq "Area") { $str = "Area Based Evaluation parameters: "; }
  else { $str = "Distance Based Evaluation parameters: "; }

  $str .= "Detection-Threshold = $det_thres (";
  if ($bin) { $str .= "Binary = True"; }
  else { $str .= "Binary = False"; }
  $str .= "); ";

  $str .= "Tracking-Threshold = $trk_thres (";
  if ($bin) { $str .= "Binary = True"; }
  else { $str .= "Binary = False"; }
  $str .= "); ";

  $str .= "Miss-Detect-Cost = $CostMiss; ";
  $str .= "False-Alarm-Cost = $CostFA; ";
  $str .= "ID-Switch-Cost = $CostIS.\n\n";

  return($str);
}

########################################

sub get_sys_ref_filelist {
  my $rlo = shift @_;
  my @args = @_;

  my @lo = @{$rlo};

  @args = reverse @args;
  @lo = reverse @lo;

  my @ref;
  my @sys;
  while (my $l = shift @lo) {
    if ($l eq $args[0]) {
      push @ref, $l;
      shift @args;
    }
  }
  @ref = reverse @ref;
  @sys = reverse @args;

  return(\@ref, \@sys);
}

########################################

sub add_data2sat {
  my ($sat, $runid, $reffilename, $sysfilename, $videofilename, 
      $evalobj, $evaltype, $sfda, $ata, $moda, $modp, $mota, $motp) = @_;

 $sfda = sprintf("%.6f", $sfda);
 $ata = sprintf("%.6f", $ata);
 $moda = sprintf("%.6f", $moda);
 $modp = sprintf("%.6f", $modp);
 $mota = sprintf("%.6f", $mota);
 $motp = sprintf("%.6f", $motp);

 $sat->addData($reffilename, "Reference File", $runid);
 $sat->addData($sysfilename, "System Output File", $runid);
 $sat->addData($videofilename, "Video", $runid);
 $sat->addData($evalobj, "Object", $runid);
 if ($evaltype eq "Area") {
     $sat->addData($sfda, "SFDA", $runid);
     $sat->addData($ata, "ATA", $runid);
     $sat->addData($moda, "MODA", $runid);
     $sat->addData($modp, "MODP", $runid);
     $sat->addData($mota, "MOTA", $runid);
     $sat->addData($motp, "MOTP", $runid);
 }
 else {
     $sat->addData($sfda, "SFDA-D", $runid);
     $sat->addData($ata, "ATA-D", $runid);
     $sat->addData($moda, "MODA", $runid);
     $sat->addData($modp, "MODP-D", $runid);
     $sat->addData($mota, "MOTA", $runid);
     $sat->addData($motp, "MOTP-D", $runid);
 }

}