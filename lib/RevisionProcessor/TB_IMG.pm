package RevisionProcessor::TB_IMG;
use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Catmandu;
use Moo;
use WWW::Mechanize;
use File::Temp qw(tempfile);

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

        my($fh,$file) = tempfile(UNLINK => 1,EXLOCK => 0);
        my $m = WWW::Mechanize->new( autocheck => 0);
        $m->get( $revision->{_url} );
        unless ( $m->success() ) {
            Catmandu->log->error( $m->content() );
            die( $m->content() );
        }
        my $res = $m->follow_link( text => 'Original Image', n => 1 );

        unless ( $res ) {
            Catmandu->log->warn("no image found on page ".$revision->{_url});
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
