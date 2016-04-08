#!/usr/bin/env perl
use Catmandu::Sane;
use Catmandu -load => ["."];
use Catmandu::Util qw(:is :array);
use MediaWikiFedora qw(:all);
use File::Temp qw(tempfile tempdir);
use Getopt::Long;
use File::Basename;
use RevisionProcessor::TB_IMG;

my $force = 0;

GetOptions(
    "force" => \$force
);

my $namespace_page = Catmandu->config->{namespace_page} // "mediawiki";
my $fedora = fedora();
my $mediawiki_importer = Catmandu->config->{mediawiki_importer} || "mediawiki";

Catmandu->importer($mediawiki_importer)->each(sub{
    my $page = shift;

    for(my $i = 0; $i < scalar( @{ $page->{revisions} }); $i++){

        my $revision = $page->{revisions}->[$i];
        my $pid = "${namespace_page}:".$page->{pageid}."_".$revision->{revid};

        my $url = $revision->{_url};

        #get page
        my $object_profile;
        {
            my $res = getObjectProfile(pid => $pid);
            if( $res->is_ok ) {

                Catmandu->log->info("object $pid: found");
                $object_profile = $res->parse_content();

            } else {

                Catmandu->log->warn("object $pid: not yet in fedora");
                return;

            }
        }
        #add datastream TB_IMG
        {
            my $p = RevisionProcessor::TB_IMG->new(
                fedora => $fedora,
                page => $page,
                revision => $revision,
                pid => $pid,
                dsID => "TB_IMG",
                force => $force
            );
            $p->process();
            $p->insert();
            $p->cleanup();
        }


    }

});
