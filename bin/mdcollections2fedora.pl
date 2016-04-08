#!/usr/bin/env perl
use Catmandu::Sane;
use Catmandu -load => ["."];
use Catmandu::Util qw(:is :array);
use MediaWikiFedora qw(:all);
use File::Temp qw(tempfile tempdir);
use Getopt::Long;
use LWP::UserAgent;
use File::Basename;
use HTML::TreeBuilder::XPath;
use RDF::Trine::Serializer;
use Data::UUID;

my $delete;
GetOptions(
    "delete" => \$delete
);

my $fedora = fedora();
my $namespace_collection = Catmandu->config->{namespace_collection} // "mediawikiCollection";
my $ownerId = Catmandu->config->{ownerId} // "mediawiki";
my $namespaces = rdf_namespaces();
my $all_collections_url = "https://manuscriptdesk.uantwerpen.be/md/Special:AllCollections";

my $ua = LWP::UserAgent->new( cookie_jar => {} );

my @keys = ("a".."z",0..9);

for my $key(@keys){
    my $offset = 0;
    my $limit = 10;

    while(1){

        my $res = $ua->post( $all_collections_url, [ lc($key) => uc($key), offset => $offset ] );

        unless ( $res->is_success() ) {
            Catmandu->log->error( $res->content() );
            die( $res->content() );
        }
        my $tree_cols = HTML::TreeBuilder::XPath->new_from_content( $res->content() );
        my @inputs = $tree_cols->findnodes("//input[\@name='singlecollection']");
        for my $input(@inputs){
            my $collection_code = $input->attr('value');
            my $r = $ua->post( $all_collections_url, [ singlecollection => $collection_code ] );
            unless( $r->is_success ){
                Catmandu->log->error( $r->content() );
                die( $r->content );
            }
            my $tree_col = HTML::TreeBuilder::XPath->new_from_content( $r->content() );

            #insert collection?
            my $pid_collection;
            my $collection_object_profile;
            {
                my $r2 = $fedora->findObjects( terms => $collection_code );
                my $obj = $r2->is_ok ? $r2->parse_content : {};
                my $results = $obj->{results} // [];
                $collection_object_profile = scalar(@$results) ? $results->[0] : undef;
            }
            if(defined($collection_object_profile) && $delete){
                $fedora->purgeObject(pid => $collection_object_profile->{pid});
                Catmandu->log->warn("object $collection_object_profile->{pid} purged on request");
                $collection_object_profile = undef;
            }
            #empty datastream DC for collection
            unless( defined( $collection_object_profile ) ){
                $pid_collection = "$namespace_collection:".Data::UUID->new->create_str;
                my $foxml = generate_foxml({ label => $collection_code, ownerId => $ownerId });
                my $r2 = ingest( pid => $pid_collection , xml => $foxml , format => 'info:fedora/fedora-system:FOXML-1.1' );
                unless( $r2->is_ok() ){
                    Catmandu->log->error($r2->raw());
                    die($r2->raw());
                }
                Catmandu->log->info("object $pid_collection: ingested");
            }else{
                $pid_collection = $collection_object_profile->{pid};
            }
            #RELS-EXT: collection -> object
            {
                my $new_rdf = rdf_model();
                $new_rdf->add_statement(
                    rdf_statement(
                        rdf_resource("info:fedora/${pid_collection}"),
                        rdf_resource($namespaces->{'fedora-model'}."hasModel"),
                        rdf_resource("info:fedora/mediawiki:collectionCModel")
                    )
                );
                $new_rdf->add_statement(
                    rdf_statement(
                        rdf_resource("info:fedora/${pid_collection}"),
                        rdf_resource($namespaces->{rel}."isCollection"),
                        rdf_literal("true")
                    )
                );
                my @links = $tree_col->findnodes("//table[\@id='userpage-table']//a");
                for my $link(@links){
                    my $title = $link->attr('title');
                    my $r3 = $fedora->findObjects( terms => $title );
                    my $obj = $r3->is_ok ? $r3->parse_content : {};
                    my $results = $obj->{results} // [];
                    unless(scalar(@$results)){
                        Catmandu->log->error("no page found for title $title");
                        next;
                    }
                    my $page_object_profile = $results->[0];

                    $new_rdf->add_statement(
                        rdf_statement(
                            rdf_resource("info:fedora/${pid_collection}"),
                            rdf_resource($namespaces->{rel}."hasCollectionMember"),
                            rdf_resource("info:fedora/".$page_object_profile->{pid})
                        )
                    );
                    #change RELS-EXT for page itself
                    {
                        my $page_rdf = rdf_from_datastream(pid => $page_object_profile->{pid}, dsId => "RELS-EXT") || rdf_model();
                        $page_rdf->add_statement(
                            rdf_statement(
                                rdf_resource("info:fedora/".$page_object_profile->{pid}),
                                rdf_resource($namespaces->{rel}."isMemberOfCollection"),
                                rdf_resource("info:fedora/${pid_collection}")
                            )
                        );
                        rdf_change( pid => $page_object_profile->{pid}, dsId => "RELS-EXT", rdf => $page_rdf );
                    }
                }
                rdf_change(pid => $pid_collection, dsId => "RELS-EXT", rdf => $new_rdf);

            }
        }

        if(scalar(@inputs) >= $limit){
            $offset += $limit;
        }else{
            last;
        }
    }
}
