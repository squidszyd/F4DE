package RTTMList;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# KWSEval
# RTTMList.pm
#
# Original Author: Jerome Ajot
# Additions: David Joy 
#            Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# KWSEval is an experimental system.  
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
#
# $Id$

use TranscriptHolder;
@ISA = qw(TranscriptHolder);

use strict;

use Data::Dumper;
use RTTMRecord;
use RTTMSegment;
use TermList;
use TermListRecord;

use MMisc;

sub new {
  my $class = shift;
  my $rttmfile = shift;
  my $language = shift;
  my $normalizationType = shift;
  my $encoding = shift;
  my $charSplitText = shift;
  my $charSplitTextNotASCII = shift;
  my $charSplitTextDeleteHyphens = shift;
  my $bypassCoreText = MMisc::iuv($_[0], 0); 
  
  my $self = TranscriptHolder->new();
  
  $self->{FILE} = $rttmfile;
  $self->{LEXEMES} = {};
  $self->{SPEAKERS} = {};
  $self->{LEXBYSPKR} = {};
  $self->{NOSCORE} = {};
  $self->{TERMLKUP} = {};
  $self->{charSplitText} = $charSplitText;
  $self->{charSplitTextNotASCII} = $charSplitTextNotASCII;
  $self->{charSplitTextDeleteHyphens} = $charSplitTextDeleteHyphens;

  # For a quick file rewrite (if not bypassed)
  $self->{CoreText} = "";
  $self->{bypassCoreText} = $bypassCoreText;
  
  # Added to avoid overwriting in file load
  $self->{LoadedFile} = 0;

  bless $self;
  MMisc::error_quit("new RTTM failed: \n   " . $self->errormsg())
      if (! $self->setCompareNormalize($normalizationType));
  MMisc::error_quit("new RTTM failed: \n   " . $self->errormsg())
      if (! $self->setEncoding($encoding));
  MMisc::error_quit("new RTTM failed: \n   " . $self->errormsg())
      if (! $self->setLanguage($language));
    
  $self->loadFile($rttmfile) if (defined($rttmfile));

  return($self);
}

sub unitTestFind
{
  my ($rttm, $text, $exp, $thresh) = (@_);

  print "  Finding terms ($text, thresh=$thresh)...     ";
  my $out = findTermHashToArray($rttm->findTermOccurrences($text, $thresh, ""));
  if (@$out != $exp) { 
    print "Failed: ".scalar(@$out)." != $exp\n"; 
    for(my $i=0; $i<@$out; $i++) {
        print "   num $i ";
        foreach my $rttm(@{ $out->[$i] }) {
            print $rttm->{TOKEN}.":".$rttm->{BT}." ";
        }
        print "\n";
     }
    return(0);
  }
  print "OK\n";
  return(1);
}


sub unitTest
{
    my ($file1, $file2, $file2tlist, $seg_test_file) = @_;

    my $err = MMisc::check_file_r($file1);
    if (! MMisc::is_blank($err)) {
      print "Issue with needed test file ($file1) : $err\n";
      return(0);
    }
    $err = MMisc::check_file_r($file2);
    if (! MMisc::is_blank($err)) {
      print "Issue with needed test file ($file2) : $err\n";
      return(0);
    }
    $err = MMisc::check_file_r($seg_test_file);
    if (! MMisc::is_blank($err)) {
      print "Issue with needed test file ($seg_test_file) : $err\n";
      return(0);
    }

    print "Test RTTMList\n";
      
    print " Loading English File (lowerecase normalization)...          ";
    my $rttm_eng_norm = new RTTMList($file1,"english","lowercase", "", 0, 0, 0);
    print "OK\n";

    return 0 unless(unitTestFind($rttm_eng_norm, "Yates",        2,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "of the",       53, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "of the",       49, 0.01));
    return 0 unless(unitTestFind($rttm_eng_norm, "has been a",   3,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "r",            0,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "uh",           0,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "two after",    0,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "vibrant for",    0,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "s.",           11, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "karachi used", 1,  0.1));
    print " Case insenstivity\n";
    return 0 unless(unitTestFind($rttm_eng_norm, "Jacques Chirac", 2,  0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "jacques chirac", 2,  0.1));

    print " Loading English File (no normalization)...          \n";
    my $rttm_eng_nonorm = new RTTMList($file1,"english","","", 0, 0, 0);

    return 0 unless(unitTestFind($rttm_eng_nonorm, "Yates",        2, 0.1));
    return 0 unless(unitTestFind($rttm_eng_nonorm, "yates",        0, 0.1));
    return 0 unless(unitTestFind($rttm_eng_nonorm, "s.",           0, 0.1));
    return 0 unless(unitTestFind($rttm_eng_nonorm, "karachi used", 0, 0.1));

    print " Space parsing...         \n";
    return 0 unless(unitTestFind($rttm_eng_norm, "   of the",       53, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "   of    the",    53, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "of    the  ",     53, 0.1));
    return 0 unless(unitTestFind($rttm_eng_norm, "   of    the   ", 53, 0.1));
     
    print " Adjacent terms...    \n";
    return 0 unless(unitTestFind($rttm_eng_norm, "word1 word2",       3, 0.5));
    return 0 unless(unitTestFind($rttm_eng_norm, "word1 word2 word3", 2, 0.5));

    my $tlist = new TermList($file2tlist, 0, 0, 0);
    print "Loading Cantonese File (no normalization)...          \n";
    my $rttm_cant = new RTTMList($file2, $tlist->getLanguage(), $tlist->getCompareNormalize(), $tlist->getEncoding(), 0, 0, 0);

    return 0 unless(unitTestFind($rttm_cant, $tlist->{TERMS}{"TEST-00"}{TEXT}, 4, 0.5));
    return 0 unless(unitTestFind($rttm_cant, $tlist->{TERMS}{"TEST-07"}{TEXT}, 1, 0.5));
    return 0 unless(unitTestFind($rttm_cant, $rttm_cant->{LEXEMES}{"file"}{1}[0]->{TOKEN}, 2, 0.5));
    return 0 unless(unitTestFind($rttm_cant, 
                                 $rttm_cant->{LEXEMES}{"file"}{1}[14]->{TOKEN} . " " .
                                 $rttm_cant->{LEXEMES}{"file"}{1}[15]->{TOKEN}, 
                                 2, 0.5));

    #segmetsFromTimeframe tests
    print " Segmenting (1)...        ";
    my $segments1 = $rttm_eng_norm->segmentsFromTimeframe("20031209_193946_PBS_ENG", 1, 33.575, 62.375);
    print "OK\n";

    print " Segmenting (2)...        ";
    my $segments2 = $rttm_eng_norm->segmentsFromTimeframe("20031218_004126_PBS_ENG", 1, 101.439, 13.818);
    print "OK\n";

    print " Number of segments (1)...";
    if (@{ $segments1 } != 9) {
      print "FAILED\n";
      return 0;
    }
    print "OK\n";

    print " Number of segments (2)...";
    if (@{ $segments2 } != 1) {
      print "FAILED\n";
      return 0;
    }
    print "OK\n";

    print " Continuity of segs ...   ";
    for(my $i=0; $i<@{ $segments1 }-1; $i++) {
      if (@{ $segments1 }[$i]->{ET} != @{ $segments1 }[$i+1]->{BT}) {
	print "FAILED\n";
	return 0;
      }
    }
    print "OK\n";

    #special segment tests
    my $rttm_seg_test = new RTTMList($seg_test_file,"english","","", 0, 0, 0);

    my $segments3 = $rttm_seg_test->segmentsFromTimeframe("FILE01", 1, 0.0, 8.0);
    print " Starting buffer segment .. ";
    my $seg = $segments3->[0];
    if ($seg->{BT} == 0.0 && $seg->{ET} == 1.0 && $seg->{TYPE} eq 'NONSPEECH') { print "OK\n" }
    else { print "FAILED\n" and return 0 }

    print " Ending buffer segment .. ";
    $seg = $segments3->[-1];
    if ($seg->{BT} == 6.0 && $seg->{ET} == 8.0 && $seg->{TYPE} eq 'NONSPEECH') { print "OK\n" }
    else { print "FAILED\n" and return 0 }

    my $segments4 = $rttm_seg_test->segmentsFromTimeframe("FILE01", 1, 1.0, 19.0);
    $seg = $segments4->[0];
    print " Speaker overlap (1) .. ";
    if ($seg->{BT} == 1.0 && $seg->{ET} == 6.0 && $seg->{TYPE} eq 'SPEECH') { print "OK\n" }
    else { print "FAILED\n" and return 0 }

    $seg = $segments4->[2];
    print " Speaker overlap (2) .. ";
    if ($seg->{BT} = 10.0 && $seg->{ET} == 13.0 && $seg->{TYPE} eq 'SPEECH') { print "OK\n" }
    else { print "FAILED\n" and return 0 }

    $seg = $segments4->[-1];
    print " Speaker overlap (3) .. ";
    if ($seg->{BT} == 15.0 && $seg->{ET} == 20.0 && $seg->{TYPE} eq 'SPEECH') { print "OK\n" }
    else { print "FAILED\n" and return 0 }

    my $segments5 = $rttm_seg_test->segmentsFromTimeframe("FILE01", 1, 2.0, 9.0);
    $seg = $segments5->[0];
    print " Speaker overlapping timeframe (1) .. ";
    if ($seg->{BT} == 2.0 && $seg->{ET} == 3.0 && $seg->{TYPE} eq 'NONSPEECH') { print "OK\n" }
    else { print "FAILED\n" and return 0 }
    
    $seg = $segments5->[-1];
    print " Speaker overlapping timeframe (2) .. ";
    if ($seg->{BT} == 4.0 && $seg->{ET} == 11.0 && $seg->{TYPE} eq 'NONSPEECH') { print "OK\n" }
    else { print "FAILED\n" and return 0 }

    print "All Tests OK\n";
    return 1;
}

sub findTermHashToArray
{
  my $results = shift;
  
  my @outlist = ();
  foreach my $file (keys %{ $results }) {
    foreach my $chan (keys %{ $results->{$file} }) {
      push (@outlist, @{ $results->{$file}{$chan} });
    }
  }
  return \@outlist;
}

sub dumper
{  
  my ($self) = @_;
  my $save = $Data::Dumper::Maxdepth;
  $Data::Dumper::Maxdepth = 10;
  my $str = Dumper($self);  
  $Data::Dumper::Maxdepth = $save;
  return $str;
}

sub toString
{
    my ($self) = @_;
    my ($key, $tok);
    my $str = "";
    
    $str .= "Dump of RTTM File\n";
    $str .= "   File: " . $self->{FILE} . "\n";
    $str .=  "   Records:\n";
    
    foreach my $file(sort keys  %{ $self->{DATA} })
    {
        foreach my $chan(sort keys  %{ $self->{DATA}{$file} })
        {
            for (my $i=0; $i<@{ $self->{DATA}{$file}{$chan} }; $i++)
            {
                $str .= "   ".$self->{DATA}{$file}{$chan}[$i]->toString()."\n";
            }
        }
    }
    return $str;
}

##########

sub __linkEntries {
  my $self = shift @_;
  my $undefit = MMisc::iuv(@_, 0);
  
  foreach my $file (sort keys %{ $self->{LEXBYSPKR} }) {
    foreach my $chan (sort keys %{ $self->{LEXBYSPKR}{$file} }) {
      foreach my $spkr (sort keys %{ $self->{LEXBYSPKR}{$file}{$chan} }) {
        my @sortedrecs = sort {$a->{BT} <=> $b->{BT}} @{ $self->{LEXBYSPKR}{$file}{$chan}{$spkr} }; # Order Lexemes by begin time
        for (my $i = 0; $i < @sortedrecs; $i++) {
          if ($i < scalar(@sortedrecs) - 1) {
            #Link speaker records
            $self->{LEXBYSPKR}{$file}{$chan}{$spkr}[$i]->{NEXT} 
              = $undefit ? undef : $sortedrecs[$i+1];
          }
        }
      }
    }
  }
}

#####

sub loadSSVFile {
  my ($self, $rttmFile) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);

  my $err = MMisc::check_file_r($rttmFile);
  return("Problem with input file ($rttmFile): $err")
    if (! MMisc::is_blank($err));

  open(RTTM, $rttmFile) 
    or MMisc::error_quit("Unable to open for read RTTM file '$rttmFile' : $!");
  binmode(RTTM, $self->getPerlEncodingString())
    if (! MMisc::is_blank($self->{ENCODING}));

  my $linec = 0;
  my $core_text = "";
  while (my $line = <RTTM>) {
    $linec++;
    chomp($line);
    $line =~ s%\;\;.*$%%;
    next if (MMisc::is_blank($line));
    
    $line =~ s%^\s+%%;
    $line =~ s%\s+$%%;

    my @rest = split(m/\s+/, $line); 
    MMisc::error_quit("Problem with Line (#$linec): needed 9 arguments, found " . scalar @rest . " [$line]") 
        if (scalar @rest != 9);
    my ($type, $file, $chan, $bt, $dur, $text, $stype, $spkr, $conf) = @rest;

    if (uc($type) eq "LEXEME") {
      if ($self->{charSplitText}){
        $text = $self->charSplitText($text, $self->{charSplitTextNotASCII}, $self->{charSplitTextDeleteHyphens});
      }
      my @textTokens = split(/\s/, $text);
      my $initBt = $bt; 
      my $initDur = $dur;
      for (my $tok=0; $tok<@textTokens; $tok++){
        if (@textTokens > 1){
          $dur = sprintf("%.3f",($initDur / @textTokens));
          $bt = sprintf("%.3f",$initBt + $dur * $tok)
        }
        my $record = new RTTMRecord($type, $file, $chan, $bt, $dur, $textTokens[$tok], $stype, $spkr, $conf);
        push (@{ $self->{LEXEMES}{$file}{$chan} }, $record);
        #Add record to lexeme by speaker table
        push (@{ $self->{LEXBYSPKR}{$file}{$chan}{$spkr} }, $record);
        if ($stype ne "frag" && $stype ne "fp") {
          #Add record to term lookup table
          my $tok = $record->{TOKEN};
          $tok = $self->normalizeTerm($tok);
          push(@{ $self->{TERMLKUP}{$tok} }, $record);
        }
      }
    } elsif (uc($type) eq "SPEAKER") {
      push (@{ $self->{SPEAKERS}{$file}{$chan} }, new RTTMRecord($type, $file, $chan, $bt, $dur, undef, undef, $spkr, $conf) );
    } elsif (uc($type) eq "NOSCORE") {
      push (@{ $self->{NOSCORE}{$file}{$chan} }, new RTTMRecord($type, $file, $chan, $bt, $dur, undef, undef, undef, undef) );
    } else {
      ## Ignoring a lot of type
      next;
    }

    $core_text .= "$line\n"
      if ($self->{bypassCoreText} == 0);
  }
  close RTTM;

  $self->{CoreText} = $core_text;
  $self->__linkEntries();

  $self->{FILE} = $rttmFile;
  $self->{LoadedFile} = 1;
}

#####

sub saveFile {
  my ($self, $fn) = @_;
  
  MMisc::error_quit("Can not write file ($fn), since file was loaded with the \'bypassCoreText\' option on")
      if ($self->{bypassCoreText} != 0);
 
 my $to = MMisc::is_blank($fn) ? $self->{FILE} : $fn;
  # Re-adapt the file name to remove all ".memdump" (if any)
  $to = &_rm_mds($to);

  my $txt = $self->{CoreText};
  return(MMisc::writeTo($to, "", 1, 0, $txt,  undef, undef, undef, undef, undef , (! MMisc::is_blank($self->{ENCODING})) ? $self->getPerlEncodingString() : undef));
}

########## 'save' / 'load' Memmory Dump functions

my $MemDump_Suffix = ".memdump";

sub get_MemDump_Suffix { return $MemDump_Suffix; }

my $MemDump_FileHeader_cmp = "\#  KWSEval RTTMList MemDump";
my $MemDump_FileHeader_gz_cmp = $MemDump_FileHeader_cmp . " (Gzip)";
my $MemDump_FileHeader_add = "\n\n";

my $MemDump_FileHeader = $MemDump_FileHeader_cmp . $MemDump_FileHeader_add;
my $MemDump_FileHeader_gz = $MemDump_FileHeader_gz_cmp . $MemDump_FileHeader_add;

#####

sub _rm_mds {
  my ($fname) = @_;

  return($fname) if (MMisc::is_blank($fname));

  # Remove them all
  while ($fname =~ s%$MemDump_Suffix$%%) {1;}

  return($fname);
}

#####

sub save_MemDump {
  my ($self, $fname, $mode, $printw) = @_;

  $printw = MMisc::iuv($printw, 1);

  # Re-adapt the file name to remove all ".memdump" (added later in this step)
  $fname = &_rm_mds($fname);

  # remove NEXT links to simplify saving
  $self->__linkEntries(1);

  my $tmp = MMisc::dump_memory_object
    ($fname, $MemDump_Suffix, $self,
     $MemDump_FileHeader,
     ($mode eq "gzip") ? $MemDump_FileHeader_gz : undef,
     $printw, 'yaml');

  return("Problem during actual dump process", $fname)
    if ($tmp != 1);

  return("", $fname);
}

##########

sub _md_clone_value {
  my ($self, $other, $attr) = @_;

  MMisc::error_quit("Attribute ($attr) not defined in MemDump object")
      if (! exists $other->{$attr});
  $self->{$attr} = $other->{$attr};
}

#####

sub load_MemDump_File {
  my ($self, $file) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);

  my $err = MMisc::check_file_r($file);
  return("Problem with input file ($file): $err")
    if (! MMisc::is_blank($err));

  my $object = MMisc::load_memory_object($file, $MemDump_FileHeader_gz);

  my $v1 = $object->getCompareNormalize();
  my $v2 = $self->getCompareNormalize();
  return("Loaded object's CompareNormalize ($v1) different from requested ($v2)")
    if ($v1 ne $v2);

  $v1 = $object->getEncoding();
  $v2 = $self->getEncoding();
  return("Loaded object's Encoding ($v1) different from requested ($v2)")
    if ($v1 ne $v2);

  $v1 = $object->getLanguage();
  $v2 = $self->getLanguage();
  return("Loaded object's Language ($v1) different from requested ($v2)")
    if ($v1 ne $v2);

  $self->_md_clone_value($object, 'FILE');
  $self->_md_clone_value($object, 'LEXEMES');
  $self->_md_clone_value($object, 'SPEAKERS');
  $self->_md_clone_value($object, 'LEXBYSPKR');
  $self->_md_clone_value($object, 'NOSCORE');
  $self->_md_clone_value($object, 'TERMLKUP');
  $self->_md_clone_value($object, 'bypassCoreText');

  # recreate NEXT links from stripped down version
  $self->__linkEntries();

  $self->{LoadedFile} = 1;

  return("");
}

#####

sub loadFile {
  my ($self, $rttmFile) = @_;

  return("Refusing to load a file on top of an already existing object")
    if ($self->{LoadedFile} != 0);
  
  my $err = MMisc::check_file_r($rttmFile);
  return("Problem with input file ($rttmFile): $err")
    if (! MMisc::is_blank($err));

  open FILE, "<$rttmFile"
    or return("Problem opening file ($rttmFile) : $!");

  my $header = <FILE>;
  close FILE;
  chomp $header;

  return($self->load_MemDump_File($rttmFile))
    if ( ($header eq $MemDump_FileHeader_cmp)
         || ($header eq $MemDump_FileHeader_gz_cmp) );

  return($self->loadSSVFile($rttmFile));
}

########################################

sub findTermOccurrences
{
    my ($self, $term, $threshold, $info) = @_;
    
    my %outHash = ();
    $term =~ s/^\s*//;
    $term =~ s/\s*$//;
    $term = $self->normalizeTerm($term);
    my @terms = split(/\s+/, $term);
    #print Dumper (\@terms);
    #Currently no order to returned matches

    die "Error: term $info /$term/ has no constituents tokens to find\n" if (@terms == 0);
    foreach my $record (@{ $self->{TERMLKUP}{$terms[0]} })
    {
      my @tmpList = ();
      push (@tmpList, $record);
      my $termpos = 1;
      my $currecord = $record;
      my $hoprecord = $record;
      while ($termpos < @terms)
      {
	if (defined $hoprecord->{NEXT} &&
	    sprintf("%.4f", ($hoprecord->{NEXT}{BT} - $hoprecord->{ET})) <= $threshold)
	{

## This code was incorrectly placed per the 2013 evaluation plan
##
##	  if ($hoprecord->{NEXT}{STYPE} eq "frag" ||
##	      $hoprecord->{NEXT}{STYPE} eq "fp")
##	  {
##	    $hoprecord = $hoprecord->{NEXT};
##	    next;
##	  }

	  my $pattern1 = $terms[$termpos];
	  my $pattern2 = $hoprecord->{NEXT}{TOKEN};

	  if ($pattern2 =~ /^\Q$pattern1\E$/i)
	  {
	    $currecord = $hoprecord->{NEXT};
	    $hoprecord = $currecord;
	    push (@tmpList, $currecord);
	  }
	  else
	  {
	    #Next record wasn't a match
	    @tmpList = ();
	    last;
	  }
	}
	else
	{
	  #Reached the end of records for that speaker or threshold not met
	  @tmpList = ();
	  last;
	}

	$termpos++;
      }

      #push (@outList, [ @tmpList ]) if (@tmpList > 0); 
      push (@{ $outHash{$tmpList[0]->{FILE}}{$tmpList[0]->{CHAN}} }, [ @tmpList ]) if (@tmpList > 0);
    }
    return(\%outHash); 
}

sub segmentsFromTimeframe {
  my ($self, $file, $chan, $bt, $dur) = @_;

  my @segs = ();
  my $last_et = sub { return defined $segs[-1] ? $segs[-1]->{ET} : $bt };
  my $et = sprintf("%.4f", $bt + $dur);

  if (defined($self->{SPEAKERS}{$file}{$chan})) {
    foreach my $spkr_node (sort { $a->{BT} <=> $b->{BT} } @{ $self->{SPEAKERS}{$file}{$chan} }) {
      next if $spkr_node->{BT} < $bt || $spkr_node->{ET} > $et;
      
      if ($spkr_node->{BT} > &$last_et) {
	push @segs, new RTTMSegment('NONSPEECH', $file, $chan, 
				    &$last_et, $spkr_node->{BT} - &$last_et);
      }

      if (&$last_et == $spkr_node->{BT}) {
	push @segs, new RTTMSegment('SPEECH', $file, $chan, $spkr_node->{BT},
				    $spkr_node->{ET} - $spkr_node->{BT});
      }
      elsif ($segs[-1]->{TYPE} eq "SPEECH" && $spkr_node->{ET} > &$last_et) {
	$segs[-1]->{ET} = $spkr_node->{ET};
	$segs[-1]->recalc_dur;
      }
      #tag lexes
      foreach my $lex (@{ $self->{LEXBYSPKR}{$file}{$chan}{$spkr_node->{SPKR}} }) {
	$lex->{SEG} = $segs[-1] if ($lex->{BT} >= $segs[-1]->{BT} && $lex->{ET} <= $segs[-1]->{ET});
      }
    }
  }
  if (&$last_et < $et) {
    push @segs, new RTTMSegment('NONSPEECH', $file, $chan, &$last_et, $et - &$last_et);
  }
  return \@segs;
}

1;
