package SimpleAutoTable;
#
# $Id$
#
# Simple Auto Table
#
# Original Author: Jonathan Fiscus 
# Adds: Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "SimplAutoTable.pm" is an experimental system.
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

use MMisc;
use MErrorH;
use PropList;
use CSVHelper;

use Data::Dumper;

my $key_KeyColumnTxt = "KeyColumnTxt";
my $key_KeyColumnCsv = "KeyColumnCsv";
my $key_SortRowKeyTxt = "SortRowKeyTxt";
my $key_SortRowKeyCsv = "SortRowKeyCsv";

sub new {
  my ($class) = shift @_;

  my $errormsg = new MErrorH("SimpleAutoTable");

  my $self =
    {
     hasData => 0,
     data => { },
     rowLabOrder => 
     {
      ThisIDNum    => 0,
      SubIDCount   => 0,
      SubID        => {},
      width        => { icgMult => 0, icgSepMult => 0, charLen => 0 },
     },
     colLabOrder => 
     {
      ThisIDNum    => 0,
      SubIDCount   => 0,
      SubID        => {},
      width        => { icgMult => 0, icgSepMult => 0, charLen => 0 },
     },
     Properties  => new PropList(),
     errormsg    => $errormsg,
    };

  bless $self;

  $self->{Properties}->addProp($key_KeyColumnCsv, "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_KeyColumnTxt, "Keep", ("Keep", "Remove"));
  $self->{Properties}->addProp($key_SortRowKeyTxt, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->{Properties}->addProp($key_SortRowKeyCsv, "AsAdded", ("AsAdded", "Num", "Alpha"));
  $self->_set_errormsg($self->{Properties}->get_errormsg());

  return($self);
}

##########

sub setProperties(){
  my ($self, $propHT) = @_;
    
  if (! $self->{Properties}->setValueFromHash($propHT)) {
    $self->_set_erromsg("Could not set Properties: ",$self->{Properties}->get_errormsg());
    return (0);
  }
  return (1);
}
    
##########

sub unitTest {
  my $makecall = shift @_;

  print "Testing SimpleAutoTable ..." if ($makecall);

  my $sg = new SimpleAutoTable();
  $sg->addData("1",  "PartA|A|col1", "PartZ|ObjectPut");
  $sg->addData("2",  "PartA|A|col2", "PartZ|ObjectPut");
  $sg->addData("3",  "PartB|A|col3", "PartZ|ObjectPut");
  $sg->addData("4",  "PartB|A|col4", "PartZ|ObjectPut");
  $sg->addData("5",  "PartA|A|col1", "PartYY|PeopleSplitUp");
  $sg->addData("6",  "PartA|A|col2", "PartYY|PeopleSplitUp");
  $sg->addData("7",  "PartB|A|col3", "PartYY|PeopleSplitUp");
  $sg->addData("8",  "PartB|B|col4", "PartYY|PeopleSplitUp");
  $sg->addData("9",  "PartA|B|col1", "PartZ|PersonRuns");
  $sg->addData("10", "PartA|B|col2", "PartZ|PersonRuns");
  $sg->addData("11", "PartB|B|col3", "PartZ|PersonRuns");
  $sg->addData("12", "PartB|B|col4", "PartZ|PersonRuns");
  $sg->addData("13", "PartA|B|col1", "PartYY|Pointing");
  $sg->addData("14", "PartA|B|col2", "PartYY|Pointing");
  $sg->addData("15", "PartB|B|col3", "PartYY|Pointing");
  $sg->addData("16454433333333334", "PartB|B|col4", "PartYY|Pointing");

  if (! $makecall) {
    #    $sg->dump();
    return($sg->renderTxtTable(2));
  }

  MMisc::ok_quit(" OK");
}

sub _addLab(){
  my ($self, $type, $id, $val) = @_;
  my $ht = $self->{$type."LabOrder"};
    
  if (! exists($ht->{SubID}{$id}{SubIDCount})) {
    $ht->{SubID}{$id} = { thisIDNum => $ht->{SubIDCount} ++,
                          SubIDCount => 0,
                          SubID => {},
                          width => { icgMult => 0, icgSepMult => 0, charLen => 0 } };
  }

  $ht = $ht->{SubID}{$id};
    
  ### HT is now the lowest level so we can save of the length for later
  $ht->{width}{charLen} = length($val) if ($ht->{width}{charLen} < length($val));
    
}

sub _getNumLev(){
  my ($self, $ht) = @_;
  my $numLev = 0;
  my @tmp = keys %{ $ht->{SubID} };
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $sid = $tmp[$i];
    my $nsl = $self->_getNumLev($ht->{SubID}->{$sid});
    $numLev = (1 + $nsl) if ($numLev < (1 + $nsl));
  }
  $numLev;
}

sub _getNumColLev(){
  my ($self) = @_;
  $self->_getNumLev($self->{"colLabOrder"});
}

sub _getNumRowLev(){
  my ($self) = @_;
  $self->_getNumLev($self->{"rowLabOrder"});
}

sub _getRowLabelWidth(){
  my ($self, $ht, $lev) = @_;
    
  my $len = 0;
  if ($lev == 1) {
    ### Loop through the IDS at this level
    my @tmp = keys %{ $ht->{SubID} };
    for (my $i = 0; $i < scalar @tmp; $i++) {
      my $sid = $tmp[$i];
      $len = length($sid) if ($len < length($sid));
    }
    return $len
  } else {
    ### recur at the next level
    my @tmp = keys %{ $ht->{SubID} };
    for (my $i = 0; $i < scalar @tmp; $i++) {
      my $sid = $tmp[$i];
      my $slen = $self->_getRowLabelWidth($ht->{SubID}{$sid}, $lev - 1);
      $len = $slen if ($len < $slen);
    }
    return $len           
  }
  MMisc::error_quit("[SimpleAutoTable] Internal Error");
}

sub _getColLabelWidth(){
  my ($self, $idStr) = @_;
  my $dl = $self->{"colLabOrder"}->{SubID}{$idStr}->{width}{charLen};
  (length($idStr) > $dl) ? length($idStr) : $dl;
    
}

sub _getOrderedLabelIDs(){
  my ($self, $ht, $order) = @_;
  my @ids = ();
            
  my @sortedKeys = ();
  if ($order eq "AsAdded") {
    @sortedKeys = sort { $ht->{SubID}{$a}->{thisIDNum} <=> $ht->{SubID}{$b}->{thisIDNum}} keys %{ $ht->{SubID} };
  } elsif ($order eq "Num") {
    @sortedKeys = sort { $a <=> $b} keys %{ $ht->{SubID} };
  } elsif ($order eq "Alpha") {
    @sortedKeys = sort keys %{ $ht->{SubID} };
  } else {
    MMisc::error_quit("Internal Error SimpleAutoTable: Sort order '$order' not defined");
  }  

  for (my $i1 = 0; $i1 < scalar @sortedKeys; $i1++) {
    my $sid = $sortedKeys[$i1];
    if ($ht->{SubID}->{$sid}->{SubIDCount} > 0) {
      my @k2tmp = ($self->_getOrderedLabelIDs($ht->{SubID}->{$sid}), $order);
      for (my $i2 = 0; $i2 < scalar @k2tmp; $i2++) {
        my $labelID = $k2tmp[$i2];
        push @ids, "$sid|$labelID";
      }
    } else {
      push @ids, $sid;
    }
  }

  @ids;
}

sub _getStrForLevel(){
  my ($self, $str, $lev) = @_;
  my @a = split(/\|/, $str);    
  $a[$lev-1];
}

sub addData{
  my ($self,$val, $colid, $rowid) = @_;
    
  $self->_addLab("col", $colid, $val);
  $self->_addLab("row", $rowid, $val);
    
  if (defined($self->{data}{$colid."-".$rowid})) {
    print "Warning Datam for '$rowid $colid' has multiple instances.\n"; 
    return 1;
  }
  $self->{data}{$rowid."-".$colid} = $val;
  $self->{hasData}++;

  return(1);    
}

sub dump(){
  my ($self) = @_;
  print Dumper($self);
}

sub _nChrStr(){
  my ($self, $n, $chr) = @_;
  my $fmt = "%${n}s";
  my $str = sprintf($fmt, "");
  $str =~ s/ /$chr/g;
  $str;
}

sub _leftJust(){
  my ($self, $str, $len) = @_;
  $str . $self->_nChrStr($len - length($str), " ");
}

sub _rightJust(){
  my ($self, $str, $len) = @_;
  $self->_nChrStr($len - (defined($str) ? length($str) : 0), " ") . (defined($str) ? $str : "");
}

sub _centerJust(){
  my ($self, $str, $len) = @_;
  my $left = sprintf("%d", ($len - length($str)) / 2);
  my $right = $len - (length($str) + $left);
  $self->_nChrStr($left, " ") . $str . $self->_nChrStr($right, " ");
}

sub renderTxtTable(){
  my ($self, $interColGap) = @_;
  
  my $gapStr = sprintf("%${interColGap}s","");
  
  my $numColLev = $self->_getNumColLev();
  my $numRowLev = $self->_getNumRowLev();
  
  my $out = "";
  
  #    print Dumper($self);
  
  #    print "Col num lev = $numColLev\n";
  #    print "Row num lev = $numRowLev\n";

  my $keyCol = $self->{Properties}->getValue($key_KeyColumnTxt);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the ".$key_KeyColumnTxt." property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my $r1c = ($keyCol eq "Remove") ? 1 : 0;
    
  ### Compute the max width of the row labels for each level
  my $maxRowLabWidth = $interColGap;
  my @rowLabWidth = ();
  for (my $rl=1; $rl <= $numRowLev; $rl++) {
    my $w = $self->_getRowLabelWidth($self->{rowLabOrder}, $rl);
    push @rowLabWidth, $w; 
    $maxRowLabWidth += $w + ($rl > 1 ? $interColGap : 0);    
  }
  #    print "MaxRowWidth    $maxRowLabWidth = ".join(" ",@rowLabWidth)."\n";

  #######################################################
  my ($r, $c, $fmt, $str, $rowIDStr, $colIDStr) = ("", "", "", "", "", "");

  #    print "The Report\n";
  my $rowSort = $self->{Properties}->getValue($key_SortRowKeyTxt);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to to return get RowSort property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, $rowSort);
  my @colIDs = $self->_getOrderedLabelIDs($self->{"colLabOrder"}, "AsAdded");
  #    print "ColIDs ".join(" ",@colIDs)."\n";

  ### Header output
  $out .= ((! $r1c) 
           ? ($self->_nChrStr($maxRowLabWidth, " ") . "|" . $gapStr)
           : $gapStr);

  my $data_len = 0;            
  for ($c= 0; $c<@colIDs; $c++) {
    $out .= $self->_centerJust($colIDs[$c],
                               $self->_getColLabelWidth($colIDs[$c]));
    $out .= $gapStr;
    $data_len += $self->_getColLabelWidth($colIDs[$c]) + $interColGap;
  }
  $out .= "\n";
        
  ### Header separator
  $out .= ((! $r1c) 
           ? ($self->_nChrStr($maxRowLabWidth, "-") . "+")
           : "") . $self->_nChrStr($data_len, "-");
  $out .= "\n";
  
  for (my $i1 = 0; $i1 < scalar @rowIDs; $i1++) {
    $rowIDStr = $rowIDs[$i1];
    if (! $r1c) {
      for ($c=1; $c<=$numRowLev; $c++) {
        $out .= $self->_leftJust($rowIDStr, $maxRowLabWidth);
      }
      $out .= "|";
    }

    for (my $i2 = 0; $i2 < scalar @colIDs; $i2++) {
      $colIDStr = $colIDs[$i2];
      $out .= "$gapStr" 
        . $self->_rightJust($self->{data}{$rowIDStr."-".$colIDStr}, 
                            $self->_getColLabelWidth($colIDStr));
    }
      
    $out .= "\n";
  }   
    
  return($out);
}

##########

sub loadCSV {
  my ($self, $file) = @_;

  return($self->_set_error_and_return_scalar("Can not load a CSV to a SimpleAutoTable which already has data", 0))
    if ($self->{hasData});
  
  open FILE, "<$file"
    or return($self->_set_error_and_return_scalar("Could not open CSV file ($file): $!\n", 0));
  my @filec = <FILE>;
  close FILE;
  chomp @filec;

  my $csvh = new CSVHelper();
  return($self->_set_error_and_return_scalar("Problem creating CSV handler", 0))
    if (! defined $csvh);
  return($self->_set_error_and_return_scalar("Problem with CSV handler: " . $csvh->get_errormsg(), 0))
    if ($csvh->error());
  
  my %csv = ();
  my %elt1 = ();
  my $inc = 0;
  for (my $j = 0; $j < scalar @filec; $j++) {
    my $line = $filec[$j];
    next if ($line =~ m%^\s*$%);

    my $key = sprintf("File: $file | Line: %012d", $inc);
    my @cols = $csvh->csvline2array($line);
    return($self->_set_error_and_return_scalar("Problem with CSV line: " . $csvh->get_errormsg(), 0))
      if ($csvh->error());
    
    if ($inc > 0) {
      $elt1{$cols[0]}++;
    } else {
      $csvh->set_number_of_columns(scalar @cols);
    }

    push @{$csv{$key}}, @cols;

    $inc++;
  }

  my $cu1cak = 1; # Can use 1st column as (master) key
  my @k1tmp = keys %elt1;
  for (my $i1 = 0; $i1 < scalar @k1tmp; $i1++) {
    my $key = $k1tmp[$i1];
    $cu1cak = 0 if ($elt1{$key} > 1);
  }
  $self->setProperties({ "$key_KeyColumnCsv" => "Remove", "$key_KeyColumnTxt" => "Remove"}) if (! $cu1cak);

  my @colIDs = ();
  my @k2tmp = sort keys %csv;
  for (my $i2 = 0; $i2 < scalar @k2tmp; $i2++) {
    my $key = $k2tmp[$i2];
    my @a = @{$csv{$key}};

    if (scalar @colIDs == 0) {
      @colIDs = @a;
      my $discard = shift @colIDs if ($cu1cak);
      next;
    }

    my $ID = "";
    if ($cu1cak) {
      $ID = shift @a;
    } else {
      $ID = $key;
    }

    for (my $i = 0; $i < scalar @a; $i++) {
      $self->addData($a[$i], $colIDs[$i], $ID);
    }
  }
  
  return(1);
}

##########

sub renderCSV {
  my ($self) = @_;
  
  my $out = "";
  
  my $keyCol = $self->{Properties}->getValue($key_KeyColumnCsv);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to get the $key_KeyColumnCsv property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my $k1c = ($keyCol eq "Keep") ? 1 : 0;

  my $rowSort = $self->{Properties}->getValue($key_SortRowKeyCsv);
  if ($self->{Properties}->error()) {
    $self->_set_errormsg("Unable to to return get the $key_SortRowKeyCsv property.  Message is ".$self->{Properties}->get_errormsg());
    return(undef);
  }
  my @rowIDs = $self->_getOrderedLabelIDs($self->{"rowLabOrder"}, $rowSort);
  my @colIDs = $self->_getOrderedLabelIDs($self->{"colLabOrder"}, "AsAdded");

  my $csvh = new CSVHelper();
  return($self->_set_error_and_return_scalar("Problem creating CSV handler", 0))
    if (! defined $csvh);
  return($self->_set_error_and_return_scalar("Problem with CSV handler: " . $csvh->get_errormsg(), 0))
    if ($csvh->error());

  ### Header output
  my @line = ();
  push @line, "MasterKey" if ($k1c);
  push @line, @colIDs;
  my $txt = $csvh->array2csvline(@line);
  return($self->_set_error_and_return_scalar("Problem with CSV array: " . $csvh->get_errormsg(), 0))
    if ($csvh->error());
  $out .= "$txt\n";
  $csvh->set_number_of_columns(scalar @line);

  # line per line
  for (my $i1 = 0; $i1 < scalar @rowIDs; $i1++) {
    my $rowIDStr = $rowIDs[$i1];
    my @line = ();
    push @line, $rowIDStr if ($k1c);
    for (my $i2 = 0; $i2 < scalar @colIDs; $i2++) {
      my $colIDStr = $colIDs[$i2];
      push @line, $self->{data}{$rowIDStr."-".$colIDStr};
    }
    my $txt = $csvh->array2csvline(@line);
    return($self->_set_error_and_return_scalar("Problem with CSV array: " . $csvh->get_errormsg(), 0))
      if ($csvh->error());
    $out .= "$txt\n";
  }
    
  return($out);
}

##########

sub add_selected_from_CSV {
  my ($self, $csvfile, $nfv, $idbase, @exp_header) = @_;
  # nfv "Not Found Value"

  my @added = ();

  return(@added) if ($self->error());

  my $err = MMisc::check_file_r($csvfile);
  return($self->_set_error_and_return_array("Problem with CSV file ($csvfile): $err", @added))
    if (! MMisc::is_blank($err));

  open CSV, "<$csvfile"
    or return($self->_set_error_and_return_array("Problem opening CSV file ($csvfile): $!", @added));

  my $csvh = new CSVHelper();
  return($self->_set_error_and_return_array("Problem creating the CSV object: " . $csvh->get_errormsg(), @added))
    if ($csvh->error());

  my $header = <CSV>;
  return($self->_set_error_and_return_array("CSV file contains no data ?", @added))
    if (! defined $header);
  my @headers = $csvh->csvline2array($header);
  return($self->_set_error_and_return_array("Problem extracting csv line:" . $csvh->get_errormsg(), @added))
    if ($csvh->error());
  return($self->_set_error_and_return_array("CSV file ($csvfile) contains no usable data", @added))
    if (scalar @headers < 2);

  my %pos = ();
  for (my $i = 0; $i < scalar @headers; $i++) {
    $pos{$headers[$i]} = $i;
  }

  $csvh->set_number_of_columns(scalar @headers);
  return($self->_set_error_and_return_array("Problem setting the number of columns for the csv file:" . $csvh->get_errormsg(), @added))
    if ($csvh->error());

  push @exp_header, @headers if (scalar @exp_header == 0);

  my $cont = 1;
  while ($cont) {
    my $line = <CSV>;
    if (MMisc::is_blank($line)) {
      $cont = 0;
      next;
    }
    
    my @linec = $csvh->csvline2array($line);
    return($self->_set_error_and_return_array("Problem extracting csv line:" . $csvh->get_errormsg(), @added))
      if ($csvh->error());

    my $id = "$idbase | CSVfile: $csvfile | Line#: $cont";
    for (my $i = 0; $i < scalar @exp_header; $i++) {
      my $col = $exp_header[$i];
      if (! exists $pos{$col}) {
        $self->addData($nfv, $col, $id);
      } else {
        $self->addData($linec[$pos{$col}], $col, $id);
      }
      return(@added) if ($self->error());
    }
    push @added, $id;

    $cont++;
  }
  close(CSV);

  return(@added);
}

############################################################

sub _set_errormsg {
  my ($self, $txt) = @_;
  $self->{errormsg}->set_errormsg($txt);
}

#####

sub get_errormsg {
  my ($self) = @_;
  return($self->{errormsg}->errormsg());
}

#####

sub error {
  my ($self) = @_;
  return($self->{errormsg}->error());
}

#####

sub clear_error {
  my ($self) = @_;
  return($self->{errormsg}->clear());
}

#####

sub _set_error_and_return_array {
  my $self = shift @_;
  my $errormsg = shift @_;
  $self->_set_errormsg($errormsg);
  return(@_);
}

#####

sub _set_error_and_return_scalar {
  $_[0]->_set_errormsg($_[1]);
  return($_[2]);
}

############################################################

1;
