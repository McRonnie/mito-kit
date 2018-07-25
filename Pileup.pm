#!/usr/bin/env perl
##Pileup Format Parser
##By: Jingyu Lou @ Bio-X, SJTU
##Version: 0.3
##0.3: 2018-07-18 rewrite into a pm file
##0.2: 2016-12-07 merge lines which pos more than 16569

package Pileup;
use strict;
use warnings;
use Data::Dumper;
require Exporter;
our @ISA = 'Exporter';
our @EXPORT = qw(samtools_mpileup parse indel_norm homo_het annotation);
our $VERSION = "0.3";


##Drainage "samtools mpileup BAM" to a filehandle
sub samtools_mpileup {
	my $bam_file = $_[0];
	open my $mpileup_in, "samtools mpileup --reference /home/jingyu/temp/hg19.chrM.fa $bam_file |";
	open my $mpileup_out, '>', \ my $mpileup;
	my $data;
#	while (<>){																##For Debug
	while (<$mpileup_in>){
		chomp;
		my @line = split;
		my ($chr, $pos, $ref, $depth, $base, $qual) = @line;
		if ($pos <= 16569){
			$data->{$pos} = \ @line;
		}
		elsif (exists $data->{$pos - 16569}){
			$data->{$pos - 16569}->[4] .= $base;
			$data->{$pos - 16569}->[5] .= $qual;
		}
		else {
			$data->{$pos - 16569} = \ @line;
		}
	}
	foreach my $pos (sort {$a <=> $b} keys %$data){
		print $mpileup_out join("\t", @{$data->{$pos}}), "\n";
	}
	close $mpileup_in;
	close $mpileup_out;
	return $mpileup;
}


## Parse pileup format generated by "samtools mpileup", use a filehandle as input
sub parse {
	my $mpileup_fl;
	if (-e $_[0]) {
		print STDERR "Reading $_[0]\n";
		open $mpileup_fl, '<', $_[0];
	}
	else {
		open $mpileup_fl, '<', \ $_[0];
	}
    open my $raw_parse_fl, '>', \ my $raw_parse;
    print $raw_parse_fl "#Chr\tPos\tRef\tCounts\tA\tT\tG\tC\tIndels\n";
    while (<$mpileup_fl>) {
	my %Indels;
	my %Base_counts = map { $_, 0 }	qw/ A T G C /;
	my ($chr, $pos, $ref, $Counts, $bases) = (split)[0..4];
	$ref = uc $ref;
	$bases = uc $bases;
	my @dNTPs = qw/ A T G C /;
	next unless (defined $bases);

	##count indels##
	while($bases =~ /[-+](\d+)/) {
		$bases =~ /\Q$&\E[a-zA-Z]{$1}/;
		my $one_indel = $&;
		while ($bases =~ s/\Q$one_indel\E//) {
			$Indels{$one_indel}++;
		}
	}

##transfer dot and comma to ref base and ref_reverse base##
#	my $rev = $base_rev{$ref};
	$bases =~ s/\./$ref/g;
	$bases =~ s/\,/$ref/g;

	##count A T C G##
	$bases =~ s/[^ATCG]//g;
	foreach my $dNTP (split //, $bases) {
		$Base_counts{$dNTP}++;
	}
	print $raw_parse_fl "$chr\t$pos\t$ref\t$Counts\t$Base_counts{A}\t$Base_counts{T}\t$Base_counts{G}\t$Base_counts{C}\t";
	foreach (sort { $Indels{$b} <=> $Indels{$a} } keys %Indels) {
		print $raw_parse_fl $_, ": ", $Indels{$_}, "\t"
	}
	print $raw_parse_fl "\n";
    }
    close $raw_parse_fl;
    return $raw_parse;
}






#sub merge {
#    open my $raw_parse_fl, '<', \ $_[0];
#    open my $merged_fl, '>', \ my $merged;
#   chomp(my $file = shift @ARGV);   
#   open LINE, '<', $file;
#    my %content;                              #use %content to store fixed content
 #   while (<$raw_parse_fl>) {
#	next if /#/;
#	chomp;
#	my @line = split /\t/;
#	my $pos = $line[1];
#	if ($pos <= 16569){
#		$content{$pos} = \@line;
#	} elsif (exists $content{$pos - 16569}){
#		fix(\@line);
#	} else {
#		$line[1] -= 16569;
#		$content{$pos-16569} = \@line;
#	}
 #   }
#
 #   print $merged_fl "#Chr\tPos\tRef\tCounts\tA\tT\tG\tC\tIndels\n";
  #  for my $i (1..16569){
#	my $line = defined $content{$i} ? join "\t", @{$content{$i}} : "chrM\t$i\tN\t0\t0\t0\t0\t0";
#	print $merged_fl $line, "\n";
 #   }
  #  close $merged_fl;
   # return $merged;

    #sub fix {
	#	my $fake = shift @_;
	#	my $real_pos = ${$fake}[1] - 16569;
	#	my $real = $content{$real_pos};
	#	for my $i (3..7){                             #add fake depth to real
	#		${$real}[$i] += ${$fake}[$i];
	#	}
	#	my %indels;
	#	for my $i (8..$#{$real}){
	#		$$real[$i] =~ /(.+): (\d+)/;
	#		$indels{$1} = $2;
	#	}
	#	for my $i (8..$#{$fake}){
	#		$$fake[$i] =~ /(.+): (\d+)/;
	#		$indels{$1} += $2;
	#	}
	#	my @indels;
	#	for (sort { $indels{$a} <=> $indels{$b} } keys %indels){
	#		push @indels, "$_: $indels{$_}";
	#	}
	#	@{$real} = @{$real}[0..7], @indels;
	#}
#}


sub indel_norm {
	my $parsed_in;
	if (-e $_[0]) {
		open $parsed_in, '<', $_[0];
	}
	else {
		open $parsed_in, '<', \ $_[0];
	}
	open my $normed_out, '>', \ my $normed;
	my $content;
	while ( <$parsed_in> ){
#		print;
		chomp;
		my $line = $_;
		next if m/^#/;
		my @line = split /\t/, $_;
		my $pos = $line[1];
		$content->{$pos}->{REF} = $line[2];
		$content->{$pos}->{Counts} = $line[3];
		@{$content->{$pos}}{ qw/ A T G C / } = @line[4..7];
		if ( defined $line[8] ) {
			while( $line =~ s/([-+])(\d+)([A-Za-z]+): (\d+)// ) {
				my ($indel, $drift, $base, $counts) = ( $1, $2, $3, $4 );
				my ($allele, $conversion);
				if ($indel eq '+') {																			#####INSERTION
					$conversion = $content->{$pos}->{REF} . "/" . $content->{$pos}->{REF}.$base;
#					$indel_pos = $pos;
					$allele = $conversion =~ s|/|$pos|r;
				}
				else {
					$conversion = $base . "-del";
#					$indel_pos = $pos + 1;
					$allele = $base . $pos . "d";
					my $del_start = $pos + 1;
					my $del_end = $del_start + $drift -1;
					for ( $del_start..$del_end ) {
						unless ( $_ >=16570 ) {
							$content->{$_}->{DEL} += $counts;
						}
						else {
							$content->{$_-16569}->{DEL} += $counts;
						}
					}
					my $real_pos =
						$pos + 1 > 16569 ?
						$pos -16568 :
						$pos + 1;
					$content->{$real_pos}->{INDEL}->{$conversion} =
						{
						 allele => $allele,
						 depth => $counts,
						};
				}
			}
		}
	}
	close $parsed_in;
#	if ( $debug ) {
#		print Dumper $content,"\n";
#		exit;
#	}
	say $normed_out "#Chr\tPos\tRef\tCounts\tA\tT\tG\tC\tDel";

	foreach ( sort { $a <=> $b } keys %$content ) {
		my $position = $content->{$_};
		$position->{DEL} = $position->{DEL} // 0;
#		print Dumper $position;
		foreach ( qw/ A T G C DEL / ) {
			$position->{depth} += $position->{$_};
		}
#	my $diff = $position->{depth} - $position->{Counts};
		say $normed_out "chrM\t$_\t$position->{REF}\t$position->{depth}\t$position->{A}\t$position->{T}\t$position->{G}\t$position->{C}\t$position->{DEL}";
#	say "$_\t$diff\t$position->{DEL}" if $diff;
	}

	say $normed_out "#Chr\tPos\tAllele\tInDels\tDepth";
	foreach my $pos ( sort { $a <=> $b } keys %$content ) {
		my $position = $content->{$pos};
		if ( defined $position->{INDEL} ) {
#		my $in_depth = 0;
#		foreach ( keys %{$position->{IN}->{1}} ) {
#			$in_depth += $position->{IN}->{1}->{$_};
#		}
#		say "chrM\t$\t$in_depth";
			my $INDEL_ref = $position->{INDEL};
			foreach my $conversion (sort {$INDEL_ref->{$b}->{depth} <=> $INDEL_ref->{$a}->{depth}} keys %$INDEL_ref){
				say $normed_out "chrM\t$pos\t", "$position->{INDEL}->{$conversion}->{allele}\t", "$conversion\t", "$position->{INDEL}->{$conversion}->{depth}";
			}
		}
	}
	return ($normed, $content);
	## sub
	sub _geno_format {
		my $bin_geno = sprintf "%b", ( shift @_ );
		my $format;
		next if $bin_geno == 0;
		while ( $bin_geno =~ s/[01]{1,5}$// ) {
			$format = defined $format ?
				$& . ',' . $format :
				$&;
		}
		return $format;
	}
}





#sub get_file {
#	my $file = shift @_;
#	open my $file_in, '<', $file;
#	open my $file_out, '>', \ my $file_content;
#	while (<$file_in>){
#		print $file_out $_;
#	}
#	return $file_content;
#}




###precess parsed data into homoplasy or heteroplasmy mutations
sub homo_het {
	my $min_depth = 5;
	my $hetero_threshold = 0.05;
	my $content = $_[1];
#	print Dumper($content);
	open my $homo_het_fl, '>', \ my $homo_het_out;
	print $homo_het_fl join "\t", "#Pos\tRef\tDepth\tConversion\tHomo/Het\tHet_Ratio\n";
	foreach my $pos (sort {$a <=> $b} keys %$content) {
#		print $pos, "\n", Dumper $content->{$pos} and next;
		my @indel = keys %{$content->{$pos}->{INDEL}};
#		print @indel and next;
		my @mutation = (qw/ A T G C/, @indel);
		my @conversion = map {$content->{$pos}->{REF} . "/" . $_} qw/ A T G C /;
		@conversion = (@conversion, @indel);
#		print Dumper @conversion and next;
		my %reference = map {$conversion[$_] => $mutation[$_]} (0..$#mutation);
		my @every_depth = map {$content->{$pos}->{$_}} qw/ A T G C/;
		@every_depth = (@every_depth, map {$content->{$pos}->{INDEL}->{$_}->{depth}} @indel);
		@conversion = @conversion[sort {$every_depth[$b] <=> $every_depth[$a]} (0..$#every_depth)];
		my @sorted_depth = sort {$b <=> $a} @every_depth;
#		print $pos, "\n", Dumper @conversion and next;
		if ($reference{$conversion[0]} ne $content->{$pos}->{REF}) {
			print $homo_het_fl join "\t",
				"$pos", $content->{$pos}->{REF}, $content->{$pos}->{depth}, $conversion[0], "Homo";
			print $homo_het_fl "\n";
		}
		my $het_ratio = $sorted_depth[1] / $content->{$pos}->{depth};
		if ($het_ratio >= $hetero_threshold
			and $reference{$conversion[1]} ne $content->{$pos}->{REF}
			and	$sorted_depth[1] > 1)
			{
				print $homo_het_fl join "\t",
					"$pos", $content->{$pos}->{REF}, $content->{$pos}->{depth}, $conversion[1], "Het", $het_ratio;
				print $homo_het_fl "\n";
			}
	}
	return $homo_het_out;
}


##Annotate reported loci associated with disease
sub annotation {
	my $table_path = "/home/jingyu/codes/Mito/temp/Mitochondrial-Disease.tab";
	open my $database_in, '<', $table_path;
	open my $homo_het_in, '<', \ $_[0];
	open my $annotation_fl, '>', \ my $annotation_out;
	my $data_set;
	my $note;
	<$database_in>;
	while (<$database_in>) {
		chomp;
		my @line = split;
		my ($pos_db, $locus_db, $disease_db, $allele_db, $conversion_db, $aachange_db, $homo_db, $het_db, $status_db) = @line[0..8];
		$data_set->{$pos_db} =
			{
			 $conversion_db => {
								LOCUS => $locus_db,
								AACHANGE => $aachange_db,
								HOMO => $homo_db,
								HET => $het_db,
								STATUS => $status_db,
							   },
			};
	}
	close $database_in;
	while (<$homo_het_in>) {
		next if /#/;
		chomp;
		my $ranking = 0;
		my @line = split;
		my ($pos, $ref, $depth, $conversion, $homo_het, $het_ratio) = @line;
		next unless exists $data_set->{$pos};
		my $homo = ($homo_het =~ m/\QHomo\E/) ? "+" : "-";
		my $het = ($homo_het =~ m/\QHet\E/) ? "+" : "-";
		foreach my $conversion_db (%{$data_set->{$pos}}) {
			next unless $conversion_db eq $conversion;
			my $conversion_arrow = $data_set->{$pos}->{$conversion_db};
			$het_ratio = "-" unless $het =~ m/\+/;
			$ranking++ if $homo eq $conversion_arrow->{HOMO};
			$ranking++ if $het eq $conversion_arrow->{HET};
			$ranking++ if $conversion_arrow->{STATUS} =~ m/Reported/;
			$ranking += 2 if $conversion_arrow->{STATUS} =~ m/Cfrm/;
			print $annotation_fl join "\t",
				$pos,
				$ref,
				$data_set->{$pos}->{LOCUS},
				$conversion,
				$homo,
				$het,
				$het_ratio,
				$ranking,
			}
	}
	return $annotation_out;
}




1;
