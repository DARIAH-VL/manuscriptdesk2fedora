package MediaWikiFedora;
use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(:is xml_escape);
use JSON qw();
use Catmandu::Importer::MediaWiki;
use Catmandu::FedoraCommons;
use Catmandu::Store::FedoraCommons;
use Catmandu::IdGenerator::UUID;
use File::Temp qw(tempfile);
use LWP::UserAgent;

use Exporter qw(import);

my @fedora = qw(id_generator create_id fedora ingest addDatastream modifyDatastream getDatastream getDatastreamDissemination getObjectProfile);
my @utils = qw(json to_tmp_file lwp);
our @EXPORT_OK = (@fedora,@utils);
our %EXPORT_TAGS = (
    all => [@EXPORT_OK],
    fedora => [@fedora],
    utils => [@utils]
);
sub create_id {
    id_generator()->generate();
}
sub id_generator {
    state $ig = Catmandu::IdGenerator::UUID->new();
}
sub json {
    state $json = JSON->new;
}
sub fedora {
    state $fedora = Catmandu::FedoraCommons->new( @{ Catmandu->config->{fedora} || [] } );
}
sub to_tmp_file {
    my($data,$binmode) = @_;
    $binmode ||= ":utf8";
    my($fh,$file) = tempfile(UNLINK => 1,EXLOCK => 0);
    binmode $fh,$binmode;
    print $fh $data;
    close $fh;
    $file;
}
sub getDatastream {
    fedora()->getDatastream(@_);
}
sub getDatastreamDissemination {
    fedora()->getDatastreamDissemination(@_);
}
sub addDatastream {
    fedora->addDatastream(@_);
}
sub modifyDatastream {
    fedora()->modifyDatastream(@_)
}
sub getObjectProfile {
    fedora()->getObjectProfile(@_);
}
sub ingest {
    fedora()->ingest(@_);
}
sub lwp {
    state $lwp = LWP::UserAgent->new(cookie_jar => {});
}

1;
