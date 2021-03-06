#!/usr/bin/perl -w
#
# Viewed best with tabsize 3
#
# Modified/Adapted into perl by Phil Kauffman 
#
# Remy van Elst created the original version in bash
# https://raymii.org/cms/p_Proxbash_-_Bash_script_to_manage_Proxmox_VE
#
# Macports: 
# Debian: libnet-ssh-perl
# CPAN: Net::SSH

use strict();
use warnings;
use Switch;
use Net::SSH qw(sshopen3);

our $host = "chelsea.cs.uchicago.edu";
our $user = "root";

#sub createct(){}
#sub startct(){}
#sub stopct(){}
#sub deletect(){}
#sub shelldrop(){}
#sub listcts(){}
#sub listvms(){}
#sub ctinfo(){}
#sub ctexec(){}
#sub get_storage_device_list(){}
#sub get_cttemplate_list(){}
#sub get_iso_list(){}

#print(get_cluster_nextid());
sub get_cluster_nextid() {
# usage: my $x = get_cluster_nextid();
# get next id from server, if exit code is 0 return the ID, otherwise return 0/false
	# An array is overkill, but it works nicely with the function 'array_pattern_filter'
	my @nextid = ();	

	# If the caller does not specify a host use $host configured above
   my $host = shift || $host;
	my($stdout, $stderr, $exit) = send_command($host, "pvesh get /cluster/nextid");

	# matching for: "122"
	my $pattern = q("(\d{3,})");

	# save the filtered array to @tmp
	# In this case it will only have one value at @nextid[0]
	if ( @nextid = array_pattern_filter($pattern, $stdout, $stderr, $exit)){
		# returning the nextid
		return $nextid[0];
	} else {
		# apparently you have run into the hard coded value of 10,000. Damn...
		return 0;
	}
}

# print(get_ct_list());
sub get_ct_list(){
# Returns an array of all CTs on the connected node.
	my @ctlist = 0;
	my $count = 0;	
	my @nodes = get_cluster_nodes();

	# get list of cts on each node
	# For each node...
	for (my $i = 0; $i <= $#nodes; $i++){
		# ssh into $_ and get stdout, stderr and the exit code
		my($stdout, $stderr, $exit) = send_command($nodes[$i], "pvesh get /nodes/$nodes[$i]/openvz");

		# We are looking for this pattern: "vmid" : "109"
		my $pattern = q("vmid" : "(\d{3,})");
	
		# Append the returned array to our main ct list (@ctlist). If the return code is not 0.
		if ( my @tmp = array_pattern_filter($pattern, $stdout, $stderr, $exit)){
			push(@ctlist, @tmp);
		}
	}
	# If our array ctlist is populated with ctids return it, otherwise return 0
	if (@ctlist){ return @ctlist; } else { return 0; }
}


# sub get_vm_list(){}
#my @tmp = get_cluster_nodes($host);
#print_array(@tmp);
sub get_cluster_nodes(){
# Returns an array of all nodes in the cluster

	# If the caller does not specify a host use $host configured above
	my $host = shift || $host;	

	# send command to host provided in configuration, at the top
	my($stdout, $stderr, $exit) = send_command($host, "pvesh get /nodes");
	
	# if the above command exited cleanly, continue.
	if ($exit == 0 ){
	
		# match anything in between the quotes: "node" : "nodename",
		my $pattern = qr/"node" : "(.*)",/;

		# save returned array to nice variable name
		my @nodes = array_pattern_filter($pattern, $stdout, $stderr, $exit);

	} else {
		# command did not exit successfully, return false/0
		return 0; 
	}

	# If @nodes is populated, return the array @nodes, otherwise return false/0
	if ( @nodes ){ return @nodes; } else { return 0; }
}



sub send_command(){
# sends a command to a given hoset and return stdout, stderr, and exit code
   my($user, $host, $command) = @_;

   my $pid = sshopen3("$user\@$host", undef, *OUT, *ERR, $command);
   waitpid( $pid, 0 ) or die "ERROR: $!\n";
   my $exit = $?;
   my $stdout = do { local $/; <OUT> };
   my $stderr = do { local $/; <ERR> };

   return($stdout, $stderr, $exit);
}
$command = "pvesh get /nodes";
my($stdout, $stderr, $exit) = send_command($user, $host, $command);
print $stdout;

sub array_pattern_filter(){
# Function takes an input pattern, stdout, stderr and an exit code
# and will return an array of only the content on which you matched.    
	my($pattern, $stdout, $stderr, $exit) = @_;

	if (!$exit) {
		# perl magic to return an array that is filtered on $pattern which is a string.
		# This returns an array.
		return ( $stdout =~ /$pattern/gs);
	} else {
		return 0;
	}
}

sub print_array(){
# used for debug only: Will print out the entire contents of a 1D array.
	my @array = @_;
	# print every value in @array
	foreach(@array){
		print "$_\n";
	}
}

sub usage() {
	printf("Create oVZ VM:\n");
	printf("$0 createct node-hostname node-password node-template node-ram node-disk node-ip\n");
	printf("Example: $0 createct prod001 supersecret1 ubuntu12 1024 15  172.20.5.48\n");
	printf("\n");
	printf("Start vm:\n");
	printf("$0 startct\n");
	printf("\n");
	printf("Stop vm:\n");
	printf("$0 stopct\n");
	printf("\n");
	printf("Remove vm:\n");
	printf("$0 deletect\n");
	printf("\n");
	printf("List all containers (OpenVZ):\n");
	printf("$0 listcts\n");
	printf("\n");
	printf("Get CT info:\n");
	printf("$0 ctinfo\n");
	printf("\n");
	printf("List all virtual machines (KVM)\n");
	printf("$0 listvms\n");
	printf("\n");
	printf("Execute command in ct:\n");
	printf("$0 execinct ID COMMAND\n");
	printf("Example: $0 execinct 103 \"apt-get update; apt-get -y upgrade\" \n");
	printf("\n");
	printf("Shell dropper\n");
	printf("$0 shelldrop CTID");
	printf("$0 shelldrop 101\n");
}

=begin comment
my $action;
if ($ARGV[0]){
	$action = $ARGV[0];	
}

switch ($action) {
	case "createct"	{ createct($ARGV[1], $ARGV[2], $ARGV[3], $ARGV[4], $ARGV[5], $ARGV[6], $ARGV[7], $ARGV[8]) }
	case "startct"		{ startct($ARGV[1], $ARGV[2]) }
	case "stopct"		{ stopct($ARGV[1], $ARGV[2]) }
	case "deletect"	{ deletect($ARGV[1], $ARGV[2]) }
	case "shelldrop"	{ shelldrop($ARGV[1], $ARGV[2]) }
	case "listcts"		{ listcts() }
	case "listvms"		{ listvms() }
	case "ctinfo"		{ get_ct_info($ARGV[1], $ARGV[2]) }
	case "ctexec"		{ ctexec($ARGV[1], $ARGV[2]) }
	case "usage"		{ usage() }
	else					{ usage() }
}

=cut
