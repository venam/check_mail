use warnings;
use strict;
use Mail::Box::IMAP4::SSL;
use Mail::Box::IMAP4::Message;
use Mail::Address;

my $folder;

#Some Colors
my $HEADER      = "\033[95m";
my $OKBLUE      = "\033[94m";
my $OKGREEN     = "\033[92m";
my $WARNING     = "\033[93m";
my $FAIL        = "\033[91m";
my $ENDC        = "\033[0m";
my $INFO        = $HEADER . "[". $OKBLUE ."*" . $HEADER ."] ". $ENDC;
my $ARROW       = " ". $OKGREEN . ">> ". $ENDC;
my $PLUS        = $HEADER ."[" . $OKGREEN ."+" . $HEADER ."] ". $ENDC;
my $MINUS       = $HEADER ."[". $FAIL ."-". $HEADER ."] ". $ENDC;

my @unread;
my $choice;
my $emails = [];
my $read_unread = -1;

sub read_config() {
	open IN, "config.conf" or die( $MINUS . "config.conf not found\n");
	for my $r (<IN>) {
		if ( $r =~ /;/ ) {
			chomp $r;
			my @spl = split /;/ ,$r;
			if (@spl == 4) {
				push @$emails, {
					email  => $spl[0],
					passwd => $spl[1],
					server => $spl[2],
					port   => $spl[3],
				}
			}
		}
	}
	if (! defined $$emails[0] ) {
		die( $MINUS . "Nothing found in the configs file\n");
	}
}

sub print_unread() {
	my $ite = 0;
	if ( $read_unread == 0 ) {
		print $HEADER ."\t.::Unread Messages::.\n". $ENDC;
	}
	else {
		print $HEADER ."\t.::Read Messages::.\n". $ENDC;
	}
	for my $msg (@unread) {
		print $HEADER . "[" .$OKBLUE. $ite .$HEADER. "]".$ENDC."\t";
		$ite++;
		my @address = $msg->sender();
		foreach my $addr (@address) {
			print $HEADER . "Sender : ".$ENDC .$addr->format() ."\n";
		}
		print  $HEADER."\tSubject: ".$ENDC . $msg->subject() . "\n";
	}
	print $HEADER . "\t.::---------------::.\n" . $ENDC;
}


sub ask_which_email() {
	print "\n". $INFO ."Which email do you want to open:\n";
	print $HEADER .  "    -------------------------------\n" .$ENDC;
	my $ite = 0;
	for my $mail (@$emails) {
		print $HEADER ."[" . $OKBLUE  . $ite . $HEADER ."]\t". $ENDC. $mail->{email}."\n";
		$ite++;
	}
	print $HEADER .  "    -------------------------------\n" .$ENDC;
	my $current_email = -1;
	while ($current_email >= @$emails || $current_email< 0 ) {
		print $OKGREEN . " => " . $ENDC ;
		$current_email = <STDIN>;
	}
	print $HEADER . "\n\t.::Connecting::.\n\n" . $ENDC;
	if ( $$emails[$current_email]->{port} eq 'default' ) {
		$folder = new Mail::Box::IMAP4::SSL(
			username    => $$emails[$current_email]->{email},
			password    => $$emails[$current_email]->{passwd},
			server_name => $$emails[$current_email]->{server},
			folder      => '/INBOX',
			access      => 'rw',
		);
	}
}

sub ask_read_unread() {
	print $INFO . "Do you want to interact with unread messages[0] or read[1]?\n"; 
	do {
		print $OKGREEN . " => " . $ENDC;
		$read_unread = <STDIN>;
	} while ($read_unread != 0 && $read_unread != 1);
}

sub init() {
	ask_which_email();
	ask_read_unread();
	my $nb_of_msgs = $folder->messages();
	my $blah = 1;
	while ($blah) {
		$blah = pop @unread;
	}
	for my $nb (0 .. ($nb_of_msgs-1) ) {
		my $msg     =  $folder->message($nb);
		if ( $read_unread == 0) {
			if ( ! $msg->label('seen') ) {
				push @unread, $msg;
			}
		}
		else {
			if ( $msg->label('seen') ) {
				push @unread, $msg;
			}
		}
	}
	print_unread();
}

sub menu($) {
	if ( $_[0] eq 'main' ) {
		print "\n" .
			$HEADER . "A number  : ".$ENDC ." to interact with the related mesage.\n".
			$HEADER . "p/P       :" .$ENDC. " to reprint the list of messages.\n".
			$HEADER . "r/R       :" .$ENDC." reinit (email,read/unread)\n".
			$HEADER . "q/Q       :" .$ENDC." to exit.\n";
	}
	elsif ($_[0] eq 'mail' ) {
		
		print "\n" .
			$HEADER . "r/R       :" . $ENDC. " to print the content of the email.\n".
			$HEADER . "h/H       :" . $ENDC. " to view the header.\n".
			$HEADER . "s/S file  :" . $ENDC. " to save the whole message to the file.\n".
			$HEADER . "sh/Sh file:" . $ENDC. " to save the header of the message to the file.\n".
			$HEADER . "sc/Sc file:" . $ENDC. " to save the content of the message to the file.\n";
			if ( $read_unread == 0 ) {
				print  $HEADER . "x/X       :" . $ENDC. " to mark as read.\n";
			}
			print 
			$HEADER . "m/M       :" . $ENDC. " to return to the message menu.\n".
			$HEADER . "q/Q       :" . $ENDC. " to exit.\n";
	}
}

sub mail_interaction($) {
	#pgp decrypt
	my $working_on = $_[0];
	my @spl;
	while (1) {
		menu('mail');
		print $OKGREEN . "\n => " . $ENDC;
		$choice = <STDIN>;
		chomp $choice;
		if ($choice eq 'r' || $choice eq 'R') {
		#pgp decrypt
			print $unread[$working_on]->body();
			print "\n";
		}
		elsif ( $choice eq 'h' || $choice eq 'H') {
			print $unread[$working_on]->head();
			print "\n";
		}
		elsif ($choice =~ /s .+/i) {
			@spl = split / /,$choice;
			open OUT,">", $spl[1] or print $MINUS . " Cannot open file.\n";
			select OUT;
			print $unread[$working_on]->print();
			close OUT;
			select STDOUT;
		}
		elsif ($choice =~ /sh .+/i) {
			@spl = split / /,$choice;
			open OUT,">", $spl[1] or print $MINUS . " Cannot open file.\n";
			select OUT;
			print $unread[$working_on]->head();
			close OUT;
			select STDOUT;
		}
		elsif ($choice =~ /sc .+/i) {
			@spl = split / /,$choice;
			open OUT,">", $spl[1] or print $MINUS . " Cannot open file.\n";
			select OUT;
			print $unread[$working_on]->body();
			close OUT;
			select STDOUT;
		}
		elsif ( ($choice eq 'x' || $choice eq 'X' )&& $read_unread== 0 ) {
			$unread[$working_on]->label('seen',1);
		}
		elsif ( $choice eq 'm' || $choice eq 'M') {
			return;
		}
		elsif ( $choice eq 'q' || $choice eq 'Q') {
			exit(0);
		}
	}
}

sub main() {
	read_config();
	init();
	while (1) {
		menu('main');
		print $OKGREEN . "\n => " . $ENDC;
		$choice = <STDIN>;
		chomp $choice;
		if ( $choice eq 'q' || $choice eq 'Q') {
			exit(0);
		}
		elsif ($choice eq 'p' || $choice eq 'P') {
			print_unread();
		}
		elsif ($choice eq 'r' || $choice eq 'R') {
			init();
		}
		elsif ($choice =~ /d*/) {
			if ( defined $unread[$choice] ) {
				mail_interaction($choice);
			}
			else {
				print $MINUS. " No such message.\n";
			}
		}
	}
}

main();
