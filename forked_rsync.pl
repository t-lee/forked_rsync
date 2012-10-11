#    Copyright 2004-2012 Thomas Boehme (t-lee@gmx.de)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#!/usr/bin/perl -w

use strict;

use Parallel::ForkManager;
use Getopt::Long;
my @exclude = ();
&GetOptions   ("excludedir=s"       => \@exclude) || die("unknown option");

push(@exclude,"/example/log/");
push(@exclude,"/example/.htaccess");

for (@exclude)
{
    die("excludedir $_ must be absolute") unless $_ =~ /^\//;
    $_ =~ s/\/+$//; #/
}

my $maxproc_each_recursion  = 3;
my $maxrecursion            = 5;
my $recursion               = 0;    # DO NOT CHANGE
my $sourcedir   = "/example/";
my $destdir     = "hostname::destination";
my $logdir      = "/tmp";

$sourcedir =~ s/\/+$//; #/
$destdir =~ s/\/+$//; #/

if ($sourcedir =~ /'/)
{
    print gmtime()."\t$$\tERROR! \"'\" character found in source dir $sourcedir! Cannot handle this!\n";
    exit 1;
}

if ($destdir =~ /'/)
{
    print gmtime()."\t$$\tERROR! \"'\" character found in destination dir $destdir! Cannot handle this!\n";
    exit 1;
}

my $cmd  = 'rsync -avv %s --delete --force %s %s %s 1>'.${logdir}.'/rsync.%s.out 2>'.${logdir}.'/rsync.%s.err';

print gmtime()."\t$$\tSTART\n";
chdir($sourcedir) || die ("cannot chdir to $sourcedir: $!");
&sync($sourcedir);
print gmtime()."\t$$\tDONE\n";


#system($cmd) && die ("Fehler bei: $cmd: $!");

sub sync
{
    $recursion++;

    my $startdir = shift();
    my $pm = new Parallel::ForkManager($maxproc_each_recursion);

    # if there is a ' character we have to ommit this find or it will fail on bash
    # don't worry in that case this dir will not excluded
    if ($startdir =~ /'/)
    {
        print gmtime()."\t$$\t\"'\" character found! Skipping startdir $startdir\n";
        return ();
    }

    my %directories = ();
    for (split("\n",`find '$startdir' -type d -maxdepth 1 -mindepth 1`))
    {
        $directories{"$_"} = 1;
    }

    OUT: for my $directory(keys %directories)
    {
        $directory =~ s/\/+$//; #/
        for (@exclude)
        {
            if ("$directory/" =~ /^$_\//)
            {
                print gmtime()."\t$$\t$directory found in excludes. Skipping!\n";
                next OUT;
            }
        }

        if ($directory =~ /'/) # if there is a ' character we have to ommit this file or command will fail on bash
        {
            print gmtime()."\t$$\t\"'\" character found! Skipping $directory\n";
            delete $directories{"$directory"};
            next;
        }

        $pm->start and next;
        my $excludedirs = "";
        if ($recursion < $maxrecursion)
        {
            my @d = &sync($directory);
            #print "GOT BACK ($recursion): \n\t".join("\t\n",@d)."\n";
            for (@d)
            {
                #$_ =~ s/^$directory//;
                $_ =~ s/^$sourcedir//;
                $_ =~ s/^\/+/\//;  # add one leading slash and remove the others
                if ($_ =~ /'/) # if there is a ' character we have to ommit this exclude or it will fail on bash
                {
                    print gmtime()."\t$$\t\"'\" character found! Skipping exclude of \"$_\"\n";
                    next;
                }
                $excludedirs .= "--exclude '$_' ";
            }
        }
        $directory =~ s/^$sourcedir//;
        $directory =~ s/^\/+//;  # removing leading slashes /
        my $tmpcmd = sprintf($cmd,"-R",$excludedirs,"'$directory'","'$destdir'",$$,$$);
        print gmtime()."\t$$\t$tmpcmd\n";
        system($tmpcmd) && print gmtime()."\t$$\tERROR occured in command execution. Please check logfile!\n";
        $pm->finish;
    }
    $pm->wait_all_children;
    $recursion--;
    if ($recursion == 0)
    {
        my $excludedirs = "";
        for (keys %directories)
        {
            $_ =~ s/^$startdir//;
            $excludedirs .= "--exclude '$_' ";
        }

        my $tmpcmd = sprintf($cmd,"",$excludedirs,"'$sourcedir/'","'$destdir'",$$,$$);
        print gmtime()."\t$$\t$tmpcmd\n";
        system($tmpcmd) && print gmtime()."\t$$\tERROR occured in command execution. Please check logfile!\n";
    }
    return keys %directories;
}

sub verbose
{

}


=pod

=head1 Was soll es noch können?



=cut

