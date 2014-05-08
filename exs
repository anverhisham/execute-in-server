#!/usr/bin/perl 

################## -COPYRIGHTS & WARRANTY- #########################
## It is provided without any warranty of fitness
## for any purpose. You can redistribute this file
## and/or modify it under the terms of the GNU
## Lesser General Public License (LGPL) as published
## by the Free Software Foundation, either version 3
## of the License or (at your option) any later version.
## (see http://www.opensource.org/licenses for more info)
####################################################################

########################### -TODO- #################################
## 1. Add option --destination also.

## -Author: Anver Hisham <anverhisham@gmail.com>
####################################################################



######################### -Include required packages/functions ,. - ########################
use strict;
use warnings;
use POSIX;
$SIG{CHLD} = 'IGNORE';      # To avoid zombie child processes
use File::Spec;             # For using 'chdir File::Spec->updir;'
use List::Util qw(first);   # For getting first index of the search item in an Array. (Warning: the word 'first is reserved from now on!!)
use List::Util qw(sum);
use Time::HiRes qw(gettimeofday);	## -For getting time in micro-seconds resolution. (Required to create a unique temp file suffix based on current time)

use constant false => 0;
use constant true  => 1;
our $inf = exp(~0 >> 1);
our $nan = $inf / $inf;

use Cwd 'abs_path';
use File::Basename;
our($PID,$uniqueString);
## For Debugging, make following true
our $isDebugging = true;
our $printDebugInfo = true;
our $currentFileVersionNumber = '1.0';

exit main();

sub main {
    ######################### -Get the script file & folder names,PID. - ###########################
    $PID = $$;
    my $scriptFilenameWithPath = abs_path($0);
    my $scriptFoldername = $scriptFilenameWithPath;
    $scriptFoldername =~ s/\/[^\/]*$//;
    my ($scriptFileName,$callerFolderName) = (basename($0),`pwd`); chomp($callerFolderName);  # Absolute Path, Directory name without trailing '/', Script file name alone
    if($isDebugging) {
        $callerFolderName = '/MISCEL/Work/LTESimulator_Server13/BWSim/moduleTest/PreCommitTestsWeekly'; 	##'/home/anver/Temp/temp1';
        chdir $callerFolderName;
    }
    $uniqueString = "$scriptFileName$PID";

    ## -Get all input options,
    my($version) = cutOptions(\@ARGV,'bool','--version'); ## Note: All other options are discarded.
    if($version) { print "$currentFileVersionNumber\n"; exit 0;}
    my ($executeCommand) = cutOptions(\@ARGV,' ','--executeCommand');
    if(isempty($executeCommand)) { ($executeCommand) = cutOptions(\@ARGV,' ','-e'); }
    if(isempty($executeCommand)) { print "Error: Pls Specify option --executeCommand"; exit 0; }
    
    my ($password) = cutOptions(\@ARGV,' ','--password');
    if(isempty($password)) { ($password) = cutOptions(\@ARGV,' ','-p'); }
    
    my ($copyFolder) = cutOptions(\@ARGV,' ','--copyFolder');
    if(isempty($copyFolder)) { ($copyFolder) = cutOptions(\@ARGV,' ','-c'); }
    if(isempty($copyFolder)) { $copyFolder = '.'; }
    $copyFolder = `cd $copyFolder; pwd;`; chomp($copyFolder);
    my $relativePathFromCopyFolderToCallerLocation = `perl -MFile::Spec -e "print File::Spec->abs2rel(q($callerFolderName),q($copyFolder))"`; chomp($relativePathFromCopyFolderToCallerLocation);
    
    ## -Make return Copy Folder relative w.r.t callerFolder
    my ($retrieveFolder) = cutOptions(\@ARGV,' ','--retrieveFolder');
    if(isempty($retrieveFolder)) { ($retrieveFolder) = cutOptions(\@ARGV,' ','-r'); }
    if(isempty($retrieveFolder)) { $retrieveFolder = '.'; }
    $retrieveFolder = `cd $retrieveFolder; pwd;`; chomp($retrieveFolder);
    my $retrieveFolderRelative = `perl -MFile::Spec -e "print File::Spec->abs2rel(q($callerFolderName),q($retrieveFolder))"`; chomp($retrieveFolder);
    
    my ($server) = cutOptions(\@ARGV,' ','--server');
    if(isempty($server)) { ($server) = cutOptions(\@ARGV,' ','-s'); }
    $server =~ s/\/$//;
    $server =~ m/((\w+)(\@([0-9.]*)))?(\:?([0-9a-zA-Z\/]*))/;
    my ($serverUser,$serverIP,$destinationFolderInRemoteServer) = ($2,$4,$6); ##my ($serverUser) = map{s/(\w+)(\@)/$2/} ($server);   
##    my ($serverIP) = map{/\@([0-9.]*):?/} ($server);   
  ##  my ($destinationFolderInRemoteServer) = map{/([^:@]*)$/} ($server);   
    if(isempty($destinationFolderInRemoteServer)) { $destinationFolderInRemoteServer = '.'; }
    $destinationFolderInRemoteServer = "${destinationFolderInRemoteServer}/${uniqueString}";
    my $serverDestination = "";
    if(!isempty($serverIP)) { $serverDestination="$serverUser\@$serverIP:"; }
    $serverDestination = "${serverDestination}${destinationFolderInRemoteServer}";
    
    ## -Verifying/Defaulting input options
    
    #### -If input options contain --password option, then check if package 'sshpass' installed or not?..
    my($metaExCommand,$metaCopyCommand);
    if(isempty($serverUser) && isempty($serverIP)) {                            ## -If no server is specifed, then run everything locally.
        $metaExCommand = 'sh -c ';
        $metaCopyCommand = 'cp -r ';
    }
    elsif(isempty($serverUser)) {                                               ## -If server-IP is specified, but no user is specified
        print "Error: Please Specify remote-server User name !!! "; exit 0;
    }
    elsif(isempty($serverIP)) {                                                 ## -If server-UserName is specified, but no user is specified
        print "Error: Please Specify remote-server IP address !!! "; exit 0;
    }
    elsif(isPasswordlessLoginEnabled("$serverUser\@$serverIP")) {               ## -If Passwordless login Enabled
        $metaExCommand = "ssh $serverUser\@$serverIP ";
        $metaCopyCommand = "scp -r ";
    }
    elsif(!`which sshpass`) {                                                   ## -If sshpass not installed,
        print "Please install sshpass typing 'sudo apt-get install sshpass' "; exit 0;
    }
    elsif(!isempty($password)) {
        $metaExCommand = "sshpass -p \'$password\' ssh $serverUser\@$serverIP ";
        $metaCopyCommand = "sshpass -p \'$password\' scp -r ";
    }
    else {
        print "Error: Please Specify Password using --password option !!! "; exit 0;
    }
    if($printDebugInfo) {
	print "\$metaExCommand  = $metaExCommand \n \$metaCopyCommand = $metaCopyCommand \n \$destinationFolderInRemoteServer = $destinationFolderInRemoteServer \n";
	print "\$copyFolder = $copyFolder \n \$serverDestination = $serverDestination \n \$destinationFolderInRemoteServer = $destinationFolderInRemoteServer \n";
	print "\$relativePathFromCopyFolderToCallerLocation = $relativePathFromCopyFolderToCallerLocation \n \$executeCommand = $executeCommand \n \$retrieveFolderRelative = $retrieveFolderRelative \n";
    }
    print `$metaExCommand "mkdir -p $destinationFolderInRemoteServer;"`;                                                                ## -Create temp Folder in remote-server
    print `$metaCopyCommand '$copyFolder'/* '$serverDestination/';`;                                                                               ## -Copy Folder to Remote Server
    print "Created folder \"$destinationFolderInRemoteServer\" in remote server, Copied contents to it.. Now Executing commands in Remote Server... \n";
    print `$metaExCommand "cd '$destinationFolderInRemoteServer/$relativePathFromCopyFolderToCallerLocation'; $executeCommand;"`;       ## -Goto relative Caller Location in server & Execute Command
    print "Execution in remote server is over,, Now Copying the Results back to Local Machine from Server ... \n";
    print `cd $retrieveFolder; $metaCopyCommand '$serverDestination/$relativePathFromCopyFolderToCallerLocation/$retrieveFolderRelative'/* .;`;    ## -Bring back the folder from server
    print `$metaExCommand "rm -rf $destinationFolderInRemoteServer;"`;                                                                  ## -Delete the folder in remote-server
    print "Results are copied back to local machine & temp folders in remote server is deleted... \n---- Script Execution is Over ----...";
}




#################################################################################################################################
###########################################---- LOCAL FUNCTIONS ----------------################################################
#################################################################################################################################

sub cutOptions {
    my(@outputs,$iOption,$i);
    my ($refToinArgs,$delimiter,@optionStrings) = @_;
    if($delimiter eq '') { $delimiter=' '; }				## -Make space as default delimiter

    if (ref($refToinArgs)) {
        for($iOption=0; $iOption<scalar(@optionStrings); $iOption++) {
            my $output;
            my $optionString = $optionStrings[$iOption];
            for($i=0; $i<scalar(@{$refToinArgs}); $i++) {
                if($refToinArgs->[$i] !~ m/$optionString/i) {
                    next;
                }
                else {
                    $output = splice(@{$refToinArgs},$i,1);
                    if($delimiter eq 'bool') {
                        $output = true;
                    }
                    elsif($output =~ m/$optionString\s*$delimiter\s*\w+/i ) {             	## -level=1
                        $output =~ s/$optionString\s*$delimiter//i;
                    }
                    elsif($output =~ m/$optionString\s*$delimiter/i) {                 	## -level= 1
                        $output = splice(@{$refToinArgs},$i,1);
                    }
                    elsif($delimiter eq ' ') {                 				## -level 1
                        $output = splice(@{$refToinArgs},$i,1);
                    }
                    elsif($refToinArgs->[$i] =~ m/$delimiter/) {                     	## -level = 1
                        $output = splice(@{$refToinArgs},$i,1);
                        $output = splice(@{$refToinArgs},$i,1);
                    }
                    else {
                        print "Error(cutOptions): Place = for options!!!";
                        exit 0;
                    }
                    $output =~ s/\s*//;                
                    last;
                }
            }
            if(!defined($output)) {
                if($delimiter eq 'bool') {
                    $output=false;
                }
                else {
                    $output='';
                }
            }
            push(@outputs,$output);
        }
    }
    else { 														# Not a reference
        print "Error(cutOptions): First input argument is not a reference, Can't be trimmed...";
        exit 0;
    }
    trimSpacesFromBothEnd(\@outputs);
    return @outputs;
}



######### Advantage: Trim an array of array of array..... ##########
######### Input: One/Multiple references to Scalar/Array... ##########
######### Picked from multipleRun.pl  ###############
sub trimSpacesFromBothEnd {
	my $input = $_[0];
	
	if (scalar(@_)>1) { 												# Input is an array
	    foreach my $input(@_) {
		trimSpacesFromBothEnd($input);
	    }
	}
	
	if ( UNIVERSAL::isa($input,'REF') ) {							    			# Reference to a Reference
		trimSpacesFromBothEnd(${$input});
	}
	elsif ( ! ref($input) ) { 												# Not a reference
	    print "Error(trimSpacesFromBothEnd): Not a reference, Can't be trimmed...";
	    exit 0;
	}
	elsif ( UNIVERSAL::isa($input,'SCALAR')) {  										# Reference to a scalar
		chomp(${$input});
		${$input} =~ s/^\s+//g;
		${$input} =~ s/\s+$//g;		
	}
	elsif ( UNIVERSAL::isa($input,'ARRAY') ) { 										# Reference to an array
		foreach my $element(@{$input}) {
			trimSpacesFromBothEnd(\$element);
		}
	}
	elsif ( UNIVERSAL::isa($input,'HASH') ) { 										# Reference to a hash
	    print "Error(trimSpacesFromBothEnd): Reference to an hash, Can't be trimmed...";
	    exit 0;
	}
	elsif ( UNIVERSAL::isa($input,'CODE') ) { 										# Reference to a subroutine
	    print "Error(trimSpacesFromBothEnd): Reference to an subroutine, Can't be trimmed...";
	    exit 0;
	}
}



sub isempty {
    my @inputs = @_;
    my @outputs = ();
    foreach my $input(@inputs) {
        if($input =~ m/^\s*$/) {
            push(@outputs,true);
        }
        else {
            push(@outputs,false);
        }
    }
    if(length(@outputs)>1) {
        return @outputs;
    }
    else {
        return $outputs[0];
    }
}


sub isPasswordlessLoginEnabled {
    my $loginID = $_[0];
    my $outString = `ssh $loginID "echo true"`;
    chomp($outString); trimSpacesFromBothEnd(\$outString);
    if($outString =~ m/^true$/) {
        return true;
    }
    else {
        return false;
    }
}


