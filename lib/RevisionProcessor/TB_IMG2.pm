package RevisionProcessor::TB_IMG2;
use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Catmandu;
use Moo;
use File::Temp qw(tempfile);
use MediaWikiFedora qw(mediawiki);

with 'RevisionProcessor';

has files => (
    is => 'rw',
    lazy => 1,
    default => sub { []; }
);

sub process {
    my $self = $_[0];
    my $revision = $self->revision();
    my $page = $self->page();
    my $datastream = $self->datastream();

    if ( !$datastream || $self->force ) {

        #reuse user agent (with cookies!) from mediawiki api
        my $ua = mediawiki()->{ua};

        my($fh,$file) = tempfile(UNLINK => 1,EXLOCK => 0);
        my $url = $revision->{_url}."&showoriginalimage=true";
        my $res = $ua->get( $url );
        unless ( $res->is_success() ) {
            Catmandu->log->warn("revision url $revision->{_url} return status code ".$res->code());
            Catmandu->log->warn( $res->content() );
            unlink $file;
        }else{
            binmode $fh,":raw";
            print $fh $res->content();
            $self->files([ $file ]);
        }
        close $fh;

    }

}
sub insert {
    my $self = $_[0];
    my $pid = $self->pid;
    my $dsID = $self->dsID;
    my $file = $self->files->[0];
    my $datastream = $self->datastream();

    unless ( $file ) {
        return;
    }

    my %args = (
        pid => $pid,
        dsID => $dsID,
        file => $file,
        versionable => "true",
        dsLabel => "Transcribe Bentham original image",
        mimeType => "image/jpeg"
    );

    if( $datastream ) {
        if ( $self->force ) {
            Catmandu->log->info("modifying datastream $dsID of object $pid");
            my $res = $self->fedora()->modifyDatastream(%args);
            unless( $res->is_ok() ){
                Catmandu->log->error($res->raw());
                die($res->raw());
            }
        }
    }
    else{
        Catmandu->log->info("adding datastream $dsID to object $pid");

        my $res = $self->fedora()->addDatastream(%args);
        unless( $res->is_ok() ){
            Catmandu->log->error($res->raw());
            die($res->raw());
        }
    }

}
sub cleanup {
    my $self = $_[0];
    my $files = $self->files();
    for my $file(@{ $self->files() }){
        if( -f $file ){
            Catmandu->log->debug("deleting file $file");
            unlink $file;
        }
        elsif( -d $file ){
            Catmandu->log->debug("deleting directory $file");
            rmtree($file);
        }
    }
}

1;
