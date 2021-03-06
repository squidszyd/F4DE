# VidAT_TrackingLog.pm
#
# $Id$
#
# Author: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by employees of the Federal 
# Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this 
# software is not subject to copyright protection within the United States and is in the public domain. 
# 
# It is an experimental system.  
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY 
# MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

package VidAT_TrackingLog;

use strict;
use warnings;
use VidAT_VideoEdit;
use List::Util qw( max );

1;

sub new
{
	my ($class, $inFile, $rmin, $rmax, $tmpBaseDir, $doInterpolate) = @_;
	
	my $self =
	{
		inFile         => $inFile,
		appears        => undef,
		minFrame  => undef,
		maxFrame  => undef,
		frames    => undef,
		polygon   => undef,
		point     => undef,
		videoClass => undef,
		color_uref => [(251,16,15,0.8)],
		color_usys => [(255,165,0,0.8)],
		color_mref => [(28,6,253,0.8)],
		color_msys => [(54,203,53,0.8)],
		color_dcob => [(255,255,0,0.8)],
		color_clear => [(0, 0, 0, 0)],
		restrictMin => 0,
		restrictMax => 999999,
		tmpBaseDir => $tmpBaseDir,
		interpolate => $doInterpolate,
	};
	
	bless $self;
		
	if(defined($rmin) && defined($rmax))
	{
		$self->{restrictMin} = $rmin;
		$self->{restrictMax} = $rmax;
	}
	
	$self->{videoClass} = new VidAT_VideoEdit($tmpBaseDir);
	$self->loadFile();
	$self->process("polygon") if(exists($self->{polygon}));
	$self->process("point") if(exists($self->{point}));
	
	return $self;
}

=pod

=item B<loadFile>()

Load and store information of the tracking log file provided at the the creation of the object.

=cut

sub loadFile
{
	my ($self) = @_;
	
	open(FILE, "<", $self->{inFile}) or die "$!";
	
	my $frame = undef;
	
	my %objectIdType;
	
	while(<FILE>)
	{
		chomp;
		my $line = $_;
			
		if($line =~ /Evaluated Frame: (\d+)/)
		{
			$frame = int($1);
			$self->{minFrame} = $frame if(!defined($self->{minFrame}));
			$self->{maxFrame} = $frame;
			push( @{ $self->{frames} }, $frame);
		}
		
		if(defined($frame))
		{
			next if( ($frame < $self->{restrictMin}) || ($frame > $self->{restrictMax}) );
		}
		
		if(($line =~ /REF (\d+) obox\[x=(\d+) y=(\d+) w=(\d+) h=(\d+) o=(\-?\d+)\]/) || ($line =~ /REF (\d+) \[x=(\d+) y=(\d+) w=(\d+) h=(\d+) o=(\-?\d+)\]/))
		{
			my $id = int($1);
			my @tl = ($2, $3);
			my @tr = ($2+$4, $3);
			my @bl = ($2, $3+$5);
			my @br = ($2+$4, $3+$5);
			my $deg = $6;
			my @c = (($tl[0]+$br[0])/2, ($tl[1]+$br[1])/2);
			@tl = rotation(@tl, @c, $6);
			@tr = rotation(@tr, @c, $6);
			@bl = rotation(@bl, @c, $6);
			@br = rotation(@br, @c, $6);
			
			$objectIdType{$id} = "polygon";
			
			my $DCO = 0;
			$DCO = 1 if($line =~ /DCO/);
			
			$self->{polygon}{ref}{$id}{$frame}{DCO} = $DCO;
			$self->{polygon}{ref}{$id}{$frame}{MAPPED} = 0;
			push( @{ $self->{polygon}{ref}{$id}{$frame}{COORD} }, @tl, @tr, @br, @bl);
			
			$self->{appears}{ref}{$id}{$frame}{REAL} = 1;
			push(@{ $self->{videoClass}->{realFrames} }, $frame);
		}
		
		if(($line =~ /SYS (\d+) obox\[x=(\d+) y=(\d+) w=(\d+) h=(\d+) o=(\-?\d+)\]/) || ($line =~ /SYS (\d+) \[x=(\d+) y=(\d+) w=(\d+) h=(\d+) o=(\-?\d+)\]/))
		{
			my $id = int($1);
			my @tl = ($2, $3);
			my @tr = ($2+$4, $3);
			my @bl = ($2, $3+$5);
			my @br = ($2+$4, $3+$5);
			my $deg = $6;
			my @c = (($tl[0]+$br[0])/2, ($tl[1]+$br[1])/2);
			@tl = rotation(@tl, @c, $6);
			@tr = rotation(@tr, @c, $6);
			@bl = rotation(@bl, @c, $6);
			@br = rotation(@br, @c, $6);
			
			$objectIdType{$id} = "polygon";
			
			my $DCO = 0;
			$DCO = 1 if($line =~ /DCO/);
			
			$self->{polygon}{sys}{$id}{$frame}{DCO} = $DCO;
			$self->{polygon}{sys}{$id}{$frame}{MAPPED} = 0;
			push( @{ $self->{polygon}{sys}{$id}{$frame}{COORD} }, @tl, @tr, @br, @bl);
			
			$self->{appears}{sys}{$id}{$frame}{REAL} = 1;
			push(@{ $self->{videoClass}->{realFrames} }, $frame);
		}
		
		if(($line =~ /REF (\d+) point\[x=(\d+) y=(\d+)\]/) || ($line =~ /REF (\d+) \[x=(\d+) y=(\d+)\]/))
		{
			my $id = int($1);
			my @pt = ($2, $3);
			
			$objectIdType{$id} = "point";
			
			my $DCO = 0;
			$DCO = 1 if($line =~ /DCO/);
			
			$self->{point}{ref}{$id}{$frame}{DCO} = $DCO;
			$self->{point}{ref}{$id}{$frame}{MAPPED} = 0;
			push( @{ $self->{point}{ref}{$id}{$frame}{COORD} }, @pt);
			
			$self->{appears}{ref}{$id}{$frame}{REAL} = 1;
			push(@{ $self->{videoClass}->{realFrames} }, $frame);
		}
		
		if(($line =~ /SYS (\d+) point\[x=(\d+) y=(\d+)\]/) || ($line =~ /SYS (\d+) \[x=(\d+) y=(\d+)\]/))
		{
			my $id = int($1);
			my @pt = ($2, $3);
			
			$objectIdType{$id} = "point";
			
			my $DCO = 0;
			$DCO = 1 if($line =~ /DCO/);
			
			$self->{point}{sys}{$id}{$frame}{DCO} = $DCO;
			$self->{point}{sys}{$id}{$frame}{MAPPED} = 0;
			push( @{ $self->{point}{sys}{$id}{$frame}{COORD} }, @pt);
			
			$self->{appears}{sys}{$id}{$frame}{REAL} = 1;
			push(@{ $self->{videoClass}->{realFrames} }, $frame);
		}
		
		if($line =~ /Mapped : SYS (\d+) -> REF (\d+)/)
		{
			my $sysId = int($1);
			my $refId = int($2);
		
			$self->{mapped}{sys}{$sysId}{$frame} = $refId;
			$self->{mapped}{ref}{$refId}{$frame} = $sysId;

			$self->{$objectIdType{$refId}}{ref}{$refId}{$frame}{MAPPED} = 1;
			$self->{$objectIdType{$sysId}}{sys}{$sysId}{$frame}{MAPPED} = 1;
		}
	}
	
	close(FILE);
	
	$self->buildContiniousFrames();
}

=pod

=item B<rotation>(I<$x>, I<$y>, I<$cx>, I<$cy>, I<$deg>)

Provide the new coordinate of the point (I<$x>, I<$y>) after a rotation of I<$deg> degrees from the center point
(I<$cx>, I<$cy>).

=cut

sub rotation
{
	my ($x, $y, $cx, $cy, $deg) = @_;
	my $rad = $deg*3.1415926536/180;
	
	return( int(($x-$cx)*cos($rad)+($y-$cy)*sin($rad) + $cx), int(-($x-$cx)*sin($rad)+($y-$cy)*cos($rad)+$cy) );
}

=pod

=item B<buildContiniousFrames>()

Private method that goes through the frames defined in the previously loaded tracking log and defines frames present in
the log and the intermediate frame used for interpolation.

=cut

sub buildContiniousFrames
{
	my ($self) = @_;
	
	return if(!defined($self->{frames}));
	
	my @listframes = sort {$a <=> $b} @{ $self->{frames} };
	
	foreach my $id (keys %{ $self->{appears}{ref} })
	{
		for(my $i=1; $i<scalar(@listframes); $i++)
		{
			if( (exists($self->{appears}{ref}{$id}{$listframes[$i]})) &&
			    (exists($self->{appears}{ref}{$id}{$listframes[$i-1]})) )
			{
				for(my $j=$listframes[$i-1]+1; $j<=$listframes[$i]-1; $j++)
				{
					$self->{appears}{ref}{$id}{$j}{REAL} = 0;
				}
			}
		}
	}
	
	foreach my $id (keys %{ $self->{appears}{sys} })
	{
		for(my $i=1; $i<scalar(@listframes); $i++)
		{
			if( (exists($self->{appears}{sys}{$id}{$listframes[$i]})) &&
			    (exists($self->{appears}{sys}{$id}{$listframes[$i-1]})) )
			{
				for(my $j=$listframes[$i-1]+1; $j<=$listframes[$i]-1; $j++)
				{
					$self->{appears}{sys}{$id}{$j}{REAL} = 0;
				}
			}
		}
	}
}

=pod

=item B<process>(I<$object>)

Main interface method that process the data from the I<$object> object ('polygon' or 'point') to create the appropriate 
data need to be used for the display.

=cut

sub process
{
	my ($self, $object) = @_;
	
	if(exists($self->{$object}{ref}))
	{
		foreach my $refId (keys %{ $self->{$object}{ref} })
		{
			$self->processTypeId($object, "ref", $refId);
		}
	}
		
	if(exists($self->{$object}{sys}))
	{	
		foreach my $sysId (keys %{ $self->{$object}{sys} })
		{
			$self->processTypeId($object, "sys", $sysId);
		}
	}
}

=pod

=item B<process>(I<$object, I<$type>, I<$id>)

Interface method that process the data from the I<$object> object ('polygon' or 'point'), type ('ref' or 'hyp'), and the 
specific frame ID I<$id> to create the appropriate data need to be used for the display.

=cut

sub processTypeId
{
	my ($self, $object, $type, $id) = @_;
	
	# extrapolate
	my @listRealFrames = sort {$a <=> $b} keys %{ $self->{$object}{$type}{$id} };
	my $minFrame = $listRealFrames[0];
	my $maxFrame = $listRealFrames[scalar(@listRealFrames)-1];
	
	for(my $i=0; $i<scalar(@listRealFrames)-1; $i++)
	{
		my $currFrame = $listRealFrames[$i];
		my $dco = $self->{$object}{$type}{$id}{$currFrame}{DCO};
		my $mapped = $self->{$object}{$type}{$id}{$currFrame}{MAPPED};
		my $mappedId = $self->{mapped}{$type}{$id}{$currFrame};
		my @currCoord = @{ $self->{$object}{$type}{$id}{$currFrame}{COORD} };
		
		if(exists($self->{appears}{$type}{$id}{$currFrame+1}))
		{
			# a continious frame exists
			# extrapolate the polygon/point
			my $nextframe = $listRealFrames[$i+1];
			my @nextCoord = @{ $self->{$object}{$type}{$id}{$nextframe}{COORD} };
			my $length = $nextframe - $currFrame;
			
			for(my $f=$currFrame+1; $f<=$nextframe-1; $f++)
			{
				my $t = ($f-$currFrame)/$length;
				$self->{$object}{$type}{$id}{$f}{DCO} = $dco;
				$self->{$object}{$type}{$id}{$f}{MAPPED} = $mapped;
				$self->{mapped}{$type}{$id}{$f} = $mappedId if($mapped);
				
				for(my $c=0; $c<scalar(@currCoord); $c++)
				{
					push( @{ $self->{$object}{$type}{$id}{$f}{COORD} }, int( (1-$t)*$currCoord[$c] + $t*$nextCoord[$c] ) );
				}
			}
		}
	}
	
	# label Polygon
	my @listAppearsFrames = sort {$a <=> $b} keys %{ $self->{$object}{$type}{$id} };
	
	for(my $i=0; $i<scalar(@listAppearsFrames); $i++)
	{
		my $frm = $listAppearsFrames[$i];
		
		my $label = "";
		
		if($type eq "ref")
		{
			$label .= "R";
		}
		else
		{
			$label .= "S";
		}
		
		$label .= "$id";
		
		if($self->{$object}{$type}{$id}{$frm}{MAPPED})
		{
			$label .= " > ";
			
			if($type eq "ref")
			{
				$label .= "S";
			}
			else
			{
				$label .= "R";
			}
			
			$label .= "$self->{mapped}{$type}{$id}{$frm}";
		}
		
		$self->{label}{$type}{$id}{$frm}{TEXT} = $label;
		
		push( @{ $self->{label}{$type}{$id}{$frm}{COORD} }, $self->{$object}{$type}{$id}{$frm}{COORD}[0],
	                                                        max($self->{$object}{$type}{$id}{$frm}{COORD}[1]-5, 0));
	}
	
	# Snail Trail
	my $firstFrame = $listAppearsFrames[0];
	my $lastFrame = $listAppearsFrames[scalar(@listAppearsFrames)-1];

	my $prevFrame = $listAppearsFrames[0];
	my $prevDco = $self->{$object}{$type}{$id}{$prevFrame}{DCO};
	my $prevMapped = $self->{$object}{$type}{$id}{$prevFrame}{MAPPED};
	
	if($object eq "polygon")
	{	
		push( @{ $self->{snail}{$type}{$id}{$prevFrame}{$prevDco}{$prevMapped}{0}{COORD} }, 
			  int( ($self->{$object}{$type}{$id}{$prevFrame}{COORD}[4]+$self->{$object}{$type}{$id}{$prevFrame}{COORD}[6])/2 ),
			  int( ($self->{$object}{$type}{$id}{$prevFrame}{COORD}[5]+$self->{$object}{$type}{$id}{$prevFrame}{COORD}[7])/2 ) );
	}
	elsif($object eq "point")
	{
		push( @{ $self->{snail}{$type}{$id}{$prevFrame}{$prevDco}{$prevMapped}{0}{COORD} }, 
			  $self->{$object}{$type}{$id}{$prevFrame}{COORD}[0], $self->{$object}{$type}{$id}{$prevFrame}{COORD}[1]);
	}
	
	for(my $frm=$firstFrame+1; $frm<=$lastFrame; $frm++)
	{
		# Add the previous ones
		foreach my $dco (keys %{ $self->{snail}{$type}{$id}{$prevFrame} })
		{
			foreach my $mapped (keys %{ $self->{snail}{$type}{$id}{$prevFrame}{$dco} })
			{
				foreach my $index (keys %{ $self->{snail}{$type}{$id}{$prevFrame}{$dco}{$mapped} })
				{
					push( @{ $self->{snail}{$type}{$id}{$frm}{$dco}{$mapped}{$index}{COORD} },
						  @{ $self->{snail}{$type}{$id}{$prevFrame}{$dco}{$mapped}{$index}{COORD} });
				}
			}
		}
			
		if(exists($self->{$object}{$type}{$id}{$frm}))
		{
			my @currCoord = @{ $self->{$object}{$type}{$id}{$frm}{COORD} };
			my $currDco = $self->{$object}{$type}{$id}{$frm}{DCO};
			my $currMapped = $self->{$object}{$type}{$id}{$frm}{MAPPED};
			
			my $currIndex = 0;
			
			if(exists($self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped}))
			{
				my @indices = sort {$a <=> $b} keys %{ $self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped} };
				$currIndex = $indices[scalar(@indices)-1];
			}
			
			if( ($currDco == $prevDco) && ($currMapped == $prevMapped) && ($frm-$prevFrame == 1) )
			{
				my @prevCoord = @{ $self->{$object}{$type}{$id}{$prevFrame}{COORD} };
				
				if($object eq "polygon")
				{
					if( ($currCoord[4] != $prevCoord[4]) ||
						($currCoord[5] != $prevCoord[5]) ||
						($currCoord[6] != $prevCoord[6]) ||
						($currCoord[7] != $prevCoord[7]) )
					{
						push( @{ $self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped}{$currIndex}{COORD} }, 
							  int( ($currCoord[4]+$currCoord[6])/2 ), 
							  int( ($currCoord[5]+$currCoord[7])/2 ) );
					}
				}
				elsif($object eq "point")
				{
					if( ($currCoord[0] != $prevCoord[0]) ||
						($currCoord[1] != $prevCoord[1]) )
					{
						push( @{ $self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped}{$currIndex}{COORD} }, 
							  $currCoord[0], $currCoord[1]);
					}
				}
			}
			else
			{
				if($object eq "polygon")
				{
					push( @{ $self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped}{$currIndex+1}{COORD} }, 
						  int( ($currCoord[4]+$currCoord[6])/2 ), 
						  int( ($currCoord[5]+$currCoord[7])/2 ) );
				}
				elsif($object eq "point")
				{
					push( @{ $self->{snail}{$type}{$id}{$frm}{$currDco}{$currMapped}{$currIndex+1}{COORD} }, 
						  $currCoord[0], $currCoord[1]);

				}
			}
			
			$prevDco = $currDco;
			$prevMapped = $currMapped;
			$prevFrame = $frm;
		}
	}
}

=pod

=item B<addRefPolygon>(I<$size>)

Bridge method that adds the information of all the reference polygons in the data structure with a border size of I<$size> to the 
video structure that will be used to generate the drawing.

=cut

sub addRefPolygon
{
	my ($self, $size) = @_;
	
	return if(!defined($self->{polygon}));
	return if(!defined($self->{polygon}{ref}));
	
	foreach my $refId (keys %{ $self->{polygon}{ref} })
	{	
		foreach my $frm (keys %{ $self->{polygon}{ref}{$refId} })
		{
			# ignore the rest if we do not interpolate
			next if( ($self->{appears}{ref}{$refId}{$frm}{REAL} == 0) && ($self->{interpolate} == 0) );
			
			my @coord;
			push(@coord, @{ $self->{polygon}{ref}{$refId}{$frm}{COORD} });
			my $dco = $self->{polygon}{ref}{$refId}{$frm}{DCO};
			my $mapped = $self->{polygon}{ref}{$refId}{$frm}{MAPPED};
			
			my @fill;
			push(@fill, @{ $self->{color_clear} });

			if($dco == 1)
			{
				my @border;
				push(@border, @{ $self->{color_dcob} });
				
				$self->{videoClass}->addPolygon($frm, 
							   $frm, 
							   \@coord, 
							   $size,
							   \@fill, 
							   \@border,
							   1);
			}
			else
			{
				my @border;
				push(@border, ($mapped) ? @{ $self->{color_mref} } : @{ $self->{color_uref} });
			
				$self->{videoClass}->addPolygon($frm, 
							   $frm, 
							   \@coord, 
							   $size, 
							   \@fill, 
							   \@border,
							   1);			   
			}
		}
	}
}

=pod

=item B<addRefPoint>(I<$size>)

Bridge method that adds the information of all the reference points in the data structure with a border size of I<$size> to the 
video structure that will be used to generate the drawing.

=cut

sub addRefPoint
{
	my ($self, $size) = @_;
	
	return if(!exists($self->{point}));
	return if(!exists($self->{point}{ref}));
	
	foreach my $refId (keys %{ $self->{point}{ref} })
	{	
		foreach my $frm (keys %{ $self->{point}{ref}{$refId} })
		{
			# ignore the rest if we do not interpolate
			next if( ($self->{appears}{ref}{$refId}{$frm}{REAL} == 0) && ($self->{interpolate} == 0) );
			
			my @coord;
			push(@coord, @{ $self->{point}{ref}{$refId}{$frm}{COORD} });
			my $dco = $self->{point}{ref}{$refId}{$frm}{DCO};
			my $mapped = $self->{point}{ref}{$refId}{$frm}{MAPPED};
			
			if($dco == 1)
			{
				my @border;
				push(@border, @{ $self->{color_dcob} });
				
				$self->{videoClass}->addPoint($frm, 
							   $frm, 
							   \@coord, 
							   $size,
							   \@border);
			}
			else
			{
				my @border;
				push(@border, ($mapped) ? @{ $self->{color_mref} } : @{ $self->{color_uref} });
			
				$self->{videoClass}->addPoint($frm, 
							   $frm, 
							   \@coord, 
							   $size,
							   \@border);		   
			}
		}
	}
}

=pod

=item B<addSysPolygon>(I<$size>)

Bridge method that adds the information of all the system polygons in the data structure with a border size of I<$size> to the 
video structure that will be used to generate the drawing.

=cut

sub addSysPolygon
{
	my ($self, $size) = @_;
	
	return if(!defined($self->{polygon}));
	return if(!defined($self->{polygon}{sys}));
	
	foreach my $sysId (keys %{ $self->{polygon}{sys} })
	{	
		foreach my $frm (keys %{ $self->{polygon}{sys}{$sysId} })
		{
			# ignore the rest if we do not interpolate
			next if( ($self->{appears}{sys}{$sysId}{$frm}{REAL} == 0) && ($self->{interpolate} == 0) );
			
			my @coord;
			push(@coord, @{ $self->{polygon}{sys}{$sysId}{$frm}{COORD} });
			my $dco = $self->{polygon}{sys}{$sysId}{$frm}{DCO};
			my $mapped = $self->{polygon}{sys}{$sysId}{$frm}{MAPPED};
			
			my @fill;
			push(@fill, @{ $self->{color_clear} });
			
			if($dco == 1)
			{
				my @border;
				push(@border, @{ $self->{color_dcob} });
				
				$self->{videoClass}->addPolygon($frm, 
							   $frm, 
							   \@coord, 
							   $size,
							   \@fill, 
							   \@border,
							   1);
			}
			else
			{
				my @border;
				push(@border, ($mapped) ? @{ $self->{color_msys} } : @{ $self->{color_usys} });
			
				$self->{videoClass}->addPolygon($frm, 
							   $frm, 
							   \@coord, 
							   $size, 
							   \@fill, 
							   \@border,
							   1);			   
			}
		}
	}
}

=pod

=item B<addSysPoint>(I<$size>)

Bridge method that adds the information of all the system points in the data structure with a border size of I<$size> to the 
video structure that will be used to generate the drawing.

=cut

sub addSysPoint
{
	my ($self, $size) = @_;
	
	return if(!exists($self->{point}));
	return if(!exists($self->{point}{sys}));
	
	foreach my $sysId (keys %{ $self->{point}{sys} })
	{	
		foreach my $frm (keys %{ $self->{point}{sys}{$sysId} })
		{
			# ignore the rest if we do not interpolate
			next if( ($self->{appears}{sys}{$sysId}{$frm}{REAL} == 0) && ($self->{interpolate} == 0) );
			
			my @coord;
			push(@coord, @{ $self->{point}{sys}{$sysId}{$frm}{COORD} });
			my $dco = $self->{point}{sys}{$sysId}{$frm}{DCO};
			my $mapped = $self->{point}{sys}{$sysId}{$frm}{MAPPED};
			
			if($dco == 1)
			{
				my @border;
				push(@border, @{ $self->{color_dcob} });
				
				$self->{videoClass}->addPoint($frm, 
							   $frm, 
							   \@coord, 
							   $size,
							   \@border);
			}
			else
			{
				my @border;
				push(@border, ($mapped) ? @{ $self->{color_msys} } : @{ $self->{color_usys} });
			
				$self->{videoClass}->addPoint($frm, 
							   $frm, 
							   \@coord, 
							   $size,
							   \@border);		   
			}
		}
	}
}

=pod

=item B<addRefLabel>()

Bridge method that adds the information of all the reference label in the data structure to the video structure that 
will be used to generate the drawing.

=cut

sub addRefLabel
{
	my ($self) = @_;
	
	return if(!defined($self->{label}));
	return if(!defined($self->{label}{ref}));
	
	foreach my $refId (keys %{ $self->{label}{ref} })
	{	
		foreach my $frm (keys %{ $self->{label}{ref}{$refId} })
		{
			# ignore the rest if we do not interpolate
			next if( ($self->{appears}{ref}{$refId}{$frm}{REAL} == 0) && ($self->{interpolate} == 0) );
			
			my @coord;
			push(@coord, @{ $self->{label}{ref}{$refId}{$frm}{COORD} });
			
			$self->{videoClass}->addLabel($frm, 
						$frm, 
						$self->{label}{ref}{$refId}{$frm}{TEXT},
						\@coord);
		}
	}
}

=pod

=item B<addSysLabel>()

Bridge method that adds the information of all the system label in the data structure to the video structure that 
will be used to generate the drawing.

=cut

sub addSysLabel
{
	my ($self) = @_;
	
	return if(!defined($self->{label}));
	return if(!defined($self->{label}{sys}));
	
	foreach my $sysId (keys %{ $self->{label}{sys} })
	{	
		foreach my $frm (keys %{ $self->{label}{sys}{$sysId} })
		{
			# ignore the rest if we do not interpolate
			next if( ($self->{appears}{sys}{$sysId}{$frm}{REAL} == 0) && ($self->{interpolate} == 0) );
			
			my @coord;
			push(@coord, @{ $self->{label}{sys}{$sysId}{$frm}{COORD} });
			
			$self->{videoClass}->addLabel($frm, 
						$frm, 
						$self->{label}{sys}{$sysId}{$frm}{TEXT},
						\@coord);
		}
	}
}

=pod

=item B<addRefSnailTrail>(I<$size>)

Bridge method that adds the information of all the reference snail trail in the data structure with a line width of 
I<$size> to the video structure that will be used to generate the drawing.

=cut

sub addRefSnailTrail
{
	my ($self, $size) = @_;
	
	return if(!defined($self->{snail}));
	return if(!defined($self->{snail}{ref}));
		
	foreach my $refId (keys %{ $self->{snail}{ref} })
	{	
		foreach my $frm (keys %{ $self->{snail}{ref}{$refId} })
		{
			foreach my $dco (keys %{ $self->{snail}{ref}{$refId}{$frm} })
			{
				foreach my $mapped (keys %{ $self->{snail}{ref}{$refId}{$frm}{$dco} })
				{
					foreach my $index (keys %{ $self->{snail}{ref}{$refId}{$frm}{$dco}{$mapped} })
					{
						my @coord;
						push(@coord, @{ $self->{snail}{ref}{$refId}{$frm}{$dco}{$mapped}{$index}{COORD} });
			
						my @fill;
						push(@fill, @{ $self->{color_clear} });
			
						if($dco == 1)
						{
							my @border;
							push(@border, @{ $self->{color_dcob} });
							
							$self->{videoClass}->addPolygon($frm, 
										   $frm, 
										   \@coord, 
										   $size,
										   \@fill, 
										   \@border,
										   0);
						}
						else
						{
							my @border;
							push(@border, ($mapped) ? @{ $self->{color_mref} } : @{ $self->{color_uref} });
						
							$self->{videoClass}->addPolygon($frm, 
										   $frm, 
										   \@coord, 
										   $size, 
										   \@fill, 
										   \@border,
										   0);			   
						}
					}
				}
			}
		}
	}
}

=pod

=item B<addSysSnailTrail>(I<$size>)

Bridge method that adds the information of all the system snail trail in the data structure with a line width of 
I<$size> to the video structure that will be used to generate the drawing.

=cut

sub addSysSnailTrail
{
	my ($self, $size) = @_;
	
	return if(!defined($self->{snail}));
	return if(!defined($self->{snail}{sys}));
		
	foreach my $sysId (keys %{ $self->{snail}{sys} })
	{	
		foreach my $frm (keys %{ $self->{snail}{sys}{$sysId} })
		{
			foreach my $dco (keys %{ $self->{snail}{sys}{$sysId}{$frm} })
			{
				foreach my $mapped (keys %{ $self->{snail}{sys}{$sysId}{$frm}{$dco} })
				{
					foreach my $index (keys %{ $self->{snail}{sys}{$sysId}{$frm}{$dco}{$mapped} })
					{
						my @coord;
						push(@coord, @{ $self->{snail}{sys}{$sysId}{$frm}{$dco}{$mapped}{$index}{COORD} });
			
						my @fill;
						push(@fill, @{ $self->{color_clear} });
			
						if($dco == 1)
						{
							my @border;
							push(@border, @{ $self->{color_dcob} });
							
							$self->{videoClass}->addPolygon($frm, 
										   $frm, 
										   \@coord, 
										   $size,
										   \@fill, 
										   \@border,
										   0);
						}
						else
						{
							my @border;
							push(@border, ($mapped) ? @{ $self->{color_msys} } : @{ $self->{color_usys} });
						
							$self->{videoClass}->addPolygon($frm, 
										   $frm, 
										   \@coord, 
										   $size, 
										   \@fill, 
										   \@border,
										   0);			   
						}
					}
				}
			}
		}
	}
}

=pod

=item B<addTimer>()

Bridge method that adds the timer on the top left corner of all frames.

=cut

sub addTimer
{
	my ($self) = @_;
	
	my @coord = (0, 11);
	
	$self->{minFrame} = $self->{restrictMin} if( !defined($self->{minFrame}) );
	$self->{maxFrame} = $self->{restrictMax} if( !defined($self->{maxFrame}) );
	
	for(my $i=$self->{minFrame}; $i<=$self->{maxFrame}; $i++)
	{
		$self->{videoClass}->addLabel($i, $i, "Frame: $i", \@coord);
	}
}

=pod

=item B<addRefFullSnailTrail>(I<$size>)

Bridge method that adds the information of all the reference full snail trail in the data structure with a line width of 
I<$size> to the video structure that will be used to generate the drawing.

Compare to the regular snail trails, the full snail trails stay on the image even if the tracked element disappear from 
the frame. If a lot of object are tracked, using full snail trail can produce a heavy picture over time.

=cut

sub addRefFullSnailTrail
{
	my ($self, $size) = @_;
	
	return if(!defined($self->{snail}));
	return if(!defined($self->{snail}{ref}));
	
	foreach my $refId (keys %{ $self->{snail}{ref} })
	{
		# find the final trail 
		my $lastFrame = 0;
		
		foreach my $frm (keys %{ $self->{snail}{ref}{$refId} })
		{
			$lastFrame = $frm if($lastFrame < $frm);
		}
		
		foreach my $dco (keys %{ $self->{snail}{ref}{$refId}{$lastFrame} })
		{
			foreach my $mapped (keys %{ $self->{snail}{ref}{$refId}{$lastFrame}{$dco} })
			{
				foreach my $index (keys %{ $self->{snail}{ref}{$refId}{$lastFrame}{$dco}{$mapped} })
				{
					my @coord;
					push(@coord, @{ $self->{snail}{ref}{$refId}{$lastFrame}{$dco}{$mapped}{$index}{COORD} });
		
					my @fill;
					push(@fill, @{ $self->{color_clear} });
		
					if($dco == 1)
					{
						my @border;
						push(@border, @{ $self->{color_dcob} });
						
						$self->{videoClass}->addPolygon(0, 
									   999999, 
									   \@coord, 
									   $size,
									   \@fill, 
									   \@border,
									   0);
					}
					else
					{
						my @border;
						push(@border, ($mapped) ? @{ $self->{color_mref} } : @{ $self->{color_uref} });
					
						$self->{videoClass}->addPolygon(0, 
									   999999, 
									   \@coord, 
									   $size, 
									   \@fill, 
									   \@border,
									   0);			   
					}
				}
			}
		}
	}
}

=pod

=item B<addSysFullSnailTrail>(I<$size>)

Bridge method that adds the information of all the system full snail trail in the data structure with a line width of 
I<$size> to the video structure that will be used to generate the drawing.

Compare to the regular snail trails, the full snail trails stay on the image even if the tracked element disappear from 
the frame. If a lot of object are tracked, using full snail trail can produce a heavy picture over time.

=cut

sub addSysFullSnailTrail
{
	my ($self, $size) = @_;
	
	return if(!defined($self->{snail}));
	return if(!defined($self->{snail}{sys}));
	
	foreach my $sysId (keys %{ $self->{snail}{sys} })
	{
		# find the final trail 
		my $lastFrame = 0;
		
		foreach my $frm (keys %{ $self->{snail}{sys}{$sysId} })
		{
			$lastFrame = $frm if($lastFrame < $frm);
		}
		
		foreach my $dco (keys %{ $self->{snail}{sys}{$sysId}{$lastFrame} })
		{
			foreach my $mapped (keys %{ $self->{snail}{sys}{$sysId}{$lastFrame}{$dco} })
			{
				foreach my $index (keys %{ $self->{snail}{sys}{$sysId}{$lastFrame}{$dco}{$mapped} })
				{
					my @coord;
					push(@coord, @{ $self->{snail}{sys}{$sysId}{$lastFrame}{$dco}{$mapped}{$index}{COORD} });
		
					my @fill;
					push(@fill, @{ $self->{color_clear} });
		
					if($dco == 1)
					{
						my @border;
						push(@border, @{ $self->{color_dcob} });
						
						$self->{videoClass}->addPolygon(0, 
									   999999, 
									   \@coord, 
									   $size,
									   \@fill, 
									   \@border,
									   0);
					}
					else
					{
						my @border;
						push(@border, ($mapped) ? @{ $self->{color_msys} } : @{ $self->{color_usys} });
					
						$self->{videoClass}->addPolygon(0, 
									   999999, 
									   \@coord, 
									   $size, 
									   \@fill, 
									   \@border,
									   0);			   
					}
				}
			}
		}
	}
}

=pod

=item B<keepOnlyKeyFrames>(I<$size>)

Define the frames to be kept to the final product based only if the frames have been present in the tracking log.
This is used when generating jpegs only of the annotated frames in the tracking log.

=cut

sub keepOnlyKeyFrames
{
	my ($self) = @_;
	
	$self->{videoClass}->{minFrame} = 9e99;
	$self->{videoClass}->{maxFrame} = 1;
	$self->{videoClass}->{outputFrames} = undef;
	
	foreach my $frm (@{ $self->{videoClass}->{realFrames} })
	{
		$self->{videoClass}->addKeepRange($frm, $frm);
	}
}

=pod

=item B<keepOnlyKeyFramesRange>(I<$size>)

Define the frames range to be kept to the final product based only if the frames have been present in the tracking log.
This is used when generating a video where only that runs only during the annotation frames defined in the tracking log.

=cut

sub keepOnlyKeyFramesRange
{
	my ($self) = @_;
	
	$self->{videoClass}->{minFrame} = 9e99;
	$self->{videoClass}->{maxFrame} = 1;
	$self->{videoClass}->{outputFrames} = undef;
	
	my @sortedRealFrames = sort {$a <=> $b} @{ $self->{videoClass}->{realFrames} };
	my $firstKeyFrame = $sortedRealFrames[0];
	my $lastKeyFrame = $sortedRealFrames[scalar(@sortedRealFrames)-1];
	
	$self->{videoClass}->addKeepRange($firstKeyFrame, $lastKeyFrame);
}

=pod

=item B<XMLFile>(I<$size>)

Produce an XML file into the standard output representing the authoring data structure.

=cut

sub XMLFile
{
	my ($self) = @_;
	
	return $self->{videoClass}->saveXMLFile(undef);	
}
