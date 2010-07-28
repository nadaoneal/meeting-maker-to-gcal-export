#!/usr/bin/perl
# fixics.pl 
# Nada, nco2104@columbia.edu, April 23, 2010
# takes a directory full of ics and txt exports from MM from various users
# - call them googleUser.txt and googleUser.ics
#  ... in our system, the googleUser names were "uni"s, so you will see that term below
# - script makes sure that there's a txt file for every ics file
# - text export has every unique event, but misses certain kinds of data, like the description
# - ics export includes description, but is lacking certain classes of events
# - ics export also omits privacy on events
# - also, the script changes some formatting issues on dates and in the desc field
# - this script has only been tested on OS X computers! Windows computers will have linebreak issues!
#   ... will probably work on linux/unix
#
#	REQUIREMENTS:
#	<mmuser>.ics export from meeting maker (recommended: export 01-01-2009 to 12-31-2010)
#	<mmuser>.txt export from meeting maker (recommended: export 01-01-2009 to 12-31-2010)
#
# syntax: fixics.pl <directory>

$|++;
use strict;
use lib "lib";
use Date::Calc qw(Add_Delta_Days);

# CONSTANTS
my $googleDomain="apps.cul.columbia.edu";
my $outFile="-cleaned.ics";

my $debug = 0;
my $directory = '';
my %toDo;

$directory = $ARGV[0];
$directory =~ s|/+$||;  # trim redundant trailing slashes
usage("Couldn't find directory '$directory'.") unless $directory and -d $directory;

# make "to do" list of all the MM usernames with all the requirements met
makeToDoList();

# clean out each username's ics file
foreach my $mappedUser (keys %toDo) {
	cleanICS($mappedUser);
}

###### SUBS ##############

# populates %ToDo with google usernames ONLY
sub makeToDoList {
	# list all .ics files in the directory 
	opendir(DIR, "$directory");
	my @toDo = grep(/\.ics$/,readdir(DIR));
	closedir(DIR);
	
	foreach my $file (@toDo) {
		my $userName = $file;
		$userName =~ s/\.ics//;
		my $okToAdd = 1;
		
		if (-f "$directory/$userName.txt") {
			$toDo{$userName} = 1;
		} else { # txt file does not exist
			print "WARNING: No .txt file for $userName: skipping.\n";
		} # end if txt file exists

	} # end foreach my $file
} # end sub makeToDoList


# print usage note
sub usage {
	my $message = $_[0];
  	print("usage:  fixics.pl <directory> \nThe script expects to find a <uni>.txt for every <uni>.ics in <directory>.\n$message\n");
  	exit;
} # end sub usage

# takes some string and makes a random ID out of it
sub randomID {
	my $mrString = $_[0];
	my @alphanums = qw( 1 2 3 4 5 6 7 8 9 0 q w e r t y u i o p a s d f g h j k l z x c v b n m );
	my $sizeOf = @alphanums;
	my $length = 20;
	
	#remove non-alphanum characters
	$mrString =~ s/[^A-Za-z0-9]//g;
	
	# append some nonsense
	for (my $i=0; $i<$length; $i++) {
		my $mrNum = int(rand($sizeOf));
		$mrString .= @alphanums[$mrNum];
	} # done appending nonsense

	return $mrString;
} #end sub randomID

# cleans ICS file and creates userName-clean.ics file
sub cleanICS {
	#these are commented out because we no longer care about the mm user name
	#my $mmUser = $_[0];
	#my $googleUser = $toDo{$mmUser}[0];
	#my $googlePassword = $toDo{$mmUser}[1];
	
	# these are set equal to one another because I am lazy
	my $googleUser = $_[0];
	my $mmUser = $googleUser;
	
	# get ics events from ics file, private and flex events from text file
	my @icsEvents;
	my %privateEvents;
	my %flexibleEvents;
	my @bannerEvents;

	# read in private events
	open(TXTEVENT, "$directory/$mmUser.txt") || die "Cannot open $directory/$mmUser.txt for reading: $1\n";

	foreach my $line (<TXTEVENT>) {
		my ($title, $location, $date, $time, $duration, $private, $flexible);
		($title, $location, $date, $time, $duration, $private, $flexible) = split /\t/, $line;
		
		# grab banner events, flexible events, and private events
		# add all banner events to @ banner events array
		if ($time eq "-") {
			# MM doesn't have these events in the ics file!
			# import the banner events, in format:
			# ALA Annual	Washington, DC	6/24/10	-	120:00	0	0
			my %bannerEvent;
			$bannerEvent{'title'} = $title;
			$bannerEvent{'location'} = $location;
			$bannerEvent{'date'} = $date;
			$bannerEvent{'time'} = $time; 
			$bannerEvent{'duration'} = $duration; 
			$bannerEvent{'private'} = $private;
			push @bannerEvents, \%bannerEvent;
		} elsif ($private eq "1") {
			# now get private events
			my $glomTitle = $title . $date;
			$privateEvents{ $glomTitle } = $date;
		} # end if private
		
		# now duplicatively and inefficiently also get flexible events into another hash
		# an event may be flexible AND private
		# this is obviously bad programming, ugh
		if ($flexible eq "1" && $time ne "-") {
			my $glomTitle = $title . $date;
			$flexibleEvents{ $glomTitle } = $date;
		}
		
	} # end foreach TXTEVENT line
	close TXTEVENT;
	
	#foreach my $event (keys %privateEvents) {
	#	print "Private event is $event on $privateEvents{$event}.\n";
	#}
	
	# LAZED - picked different solution - find organizer line & fix
	# will be most common line when you grep for ORGANIZER
	# ORGANIZER;CN=Joyce McDonough:MAILTO:jm86@columbia.edu
	# %count = ();
	# foreach $element (@ARRAY) {
    # $count{$element}++;
	# }

	# populate hash with individual events;
	open(ICS, "$directory/$mmUser.ics") || die "Cannot open $directory/$mmUser.ics for reading: $1\n";
	my $buffer="";
	
	foreach my $line (<ICS>) {
		# gets rid of heinous ^Ms, which may be followed by extraneous spaces
		$line =~ s/\x0D\s*//g;
		if ($line =~ /BEGIN:VEVENT/ || $line =~ /END:VCALENDAR/ ) {
			# put old buffer into an event and clear out buffer
			push(@icsEvents, $buffer);
			$buffer = "";
		}
		$buffer .= "$line\n";
	}
	close ICS;
	
	# now, write out new ICS file
	open(CLEANICS, ">$directory/$mmUser$outFile") || die "Cannot open $directory/$mmUser$outFile for writing: $1\n";
	foreach my $event (@icsEvents) {
		my $private = 0;
		my $flexible = 0;
		my $dstart = ""; # e.g. TZID=America/New_York:20100503T060000
		my $dstart_time = "";			
		my $formatted_date = ""; # e.g 5/6/10
		my $date_prefix = ""; # e.g. TZID=America/New_York
		my $summary = "";
		
		my @lines = split /\n/, $event;
		
		foreach my $line (@lines) {
			if ($line =~ /DTSTART/) {
				# get the full TZID=America/New_York:20100503T060000 string into dstart
				$dstart = $line;
				$dstart =~ s/DTSTART;//g;
				
				if ($dstart =~ /(.*):.*(T.*)/) {
					$date_prefix = $1;
					$dstart_time = $2;
				} else {
					$date_prefix = "TZID=America/New_York";
					$dstart_time = "T000000";
				}
				
				# now get mm/dd/yyyy into formatted_date
				$formatted_date = $dstart;
				
				if ($formatted_date =~ /.*:(20[0-9]*)T[0-9]*$/) {
					# extract 20100506 from string
					$formatted_date = $1;
					
					# transform 20100506 into 05/06/10
					$formatted_date =~ s/20([0-9]{2})([0-9]{2})([0-9]{2})/$2\/$3\/$1/;
					
					# need to make e.g. 05/06/10 into 5/6/10
					$formatted_date =~ s/0([0-9]{1,2}\/[0-9]{2}\/[0-9]{2})/$1/;
					$formatted_date =~ s/([0-9]{1,2}\/)0([0-9]{1,2}\/[0-9]{2})/$1$2/;
				}
				
			} elsif ($line =~ /^SUMMARY.*/ ) {
				$summary = $line;
				$summary =~ s/SUMMARY://;
			} # done checking for date/summary information
			  
		} # done iterating through lines
		
		# is the tbannerEventrivate?
		if (exists($privateEvents{$summary . $formatted_date})) {
			$private = 1;
			#print "$summary on $formatted_date is private\n";
		}
		
		# is the thing flexible?
		if (exists($flexibleEvents{$summary . $formatted_date})) {
			$flexible = 1;
		}
		
		foreach my $line (split /\n/, $event) {		
			if ($line =~ /EXDATE/) {
							# if line like "EXDATE", split out into several lines and reformat
							# from this: EXDATE:20091208T000000Z,20100112T000000Z,20100209T000000Z,20100413T000000Z 
							# to this: 
							#EXDATE;TZID=America/New_York:20100531T060000
							#EXDATE;TZID=America/New_York:20100517T060000 	
							# also, EXDATE needs to have real time... 20100413T093000 not 20100413T000000
				$line =~ s/EXDATE://;
				my @exceptions = split /,/, $line;
				foreach my $exception (@exceptions) {
					$exception =~ s/Z//;
					# fix the time - MM sets it to T0000000
					$exception =~ s/T[0-9]*/$dstart_time/;
					print CLEANICS "EXDATE;$date_prefix:$exception\n";
				}
			} elsif ($line =~ /ORGANIZER.*/) {
				#if line like "ORGANIZER", then need to possibly change it
				my $newMailto = "$googleUser" . '@apps.cul.columbia.edu';
				$line =~ s/MAILTO:.*/MAILTO:$newMailto/;
				print CLEANICS "$line\n";
			} elsif ($line =~ /SUMMARY/ && ($private || $flexible)){
				#print "$line is like SUMMARY\n";
				print CLEANICS "$line\n";
				if ($private) { print CLEANICS "CLASS:PRIVATE\n"; }
				if ($flexible) { print CLEANICS "TRANSP:TRANSPARENT\n"; }
			} else {
				$line =~ s/MAILTO:([a-zA-Z0-9]*)\@columbia\.edu/MAILTO:$1\@apps\.cul\.columbia\.edu/ ;
				print CLEANICS "$line\n";
			}
			
			
			
		} # done iterating through lines
		
	} # done iterating through events
	
	
	# now add in all the bannerEvents
	foreach my $flexEvent (@bannerEvents) {
		my $title = $$flexEvent{'title'};
		my $location = $$flexEvent{'location'};
		my $duration = $$flexEvent{'duration'};
		my $private = $$flexEvent{'private'};
		my $datestamp = "20100521T204840Z";
		my $startdate = $$flexEvent{'date'};
		
		# first, check duration - we only care if it's > 1
		# also, end date is duration/24 + start date
		# duration in format 24:00 or 120:00, etc
		
		# take off the :00
		$duration =~ s/:.*//;
		# divide by 24
		$duration = int($duration / 24);
		
		# no need to continue unless duration is > 1
		if ($duration) {

			# fix $startdate
			# start date currently: 5/17/09 should be: 20090517
			# pad zeros as needed
			$startdate =~ s/^(\d)(\/.*)/0$1$2/;
			$startdate =~ s/^(\d\d\/)(\d)(\/.*)/$1X$2$3/;
			$startdate =~ s/X/0/;
			
			# now rearrange
			$startdate =~ s/(\d\d)\/(\d\d)\/(\d\d)/20$3$1$2/;
			
			# make $enddate
				# it's not this easy; e.g. add 12 days to Dec 28
				# my $enddate = $startdate + $duration;
			my $year = "20$3";
			my $month = $1;
			my $day = $2;
			($year, $month, $day) = Add_Delta_Days($year, $month, $day, $duration);
			# pad with #$%$%$# zeroes
			$day =~ s/^(\d)\z/0$1/;
			$month =~ s/^(\d)\z/0$1/;
			# done!
			my $enddate = $year . $month . $day;
			
			my $randomID = randomID($title . $startdate);

				print CLEANICS "BEGIN:VEVENT\n";
				print CLEANICS "SUMMARY:$title\n";
				print CLEANICS "LOCATION:$duration\n";
				print CLEANICS "UID:MM-GLOBAL-ID[$randomID]\n";
				print CLEANICS "DTSTART;VALUE=DATE:$startdate\n";
				print CLEANICS "DTEND;VALUE=DATE:$enddate\n";
				print CLEANICS "DTSTAMP:$datestamp\n";
				
				if ($private) {
					print CLEANICS "CLASS:PRIVATE\n";
				}
				
				print CLEANICS "TRANSP:TRANSPARENT\n";
				print CLEANICS "END:VEVENT\n";

		} # end if $duration

	} # end foreach bannerEvents
	
	print CLEANICS "END:VCALENDAR\n";
	close CLEANICS;
	
	print "Finished user $mmUser.\n";
	
} #end sub cleanICS