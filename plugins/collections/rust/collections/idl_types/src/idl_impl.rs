use idl_internal::{StreamInstance, StreamReceiver, StreamSender, Uuid};
pub trait PhotosInstance {
    fn pictures_directory(&mut self, stream_instance: Box<dyn StreamInstance + Send>);
    fn pictures_directory_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream_receiver: StreamReceiver,
    ) -> StreamSender<crate::PicturesDirectory>;
    fn directory(&mut self, id: Uuid, stream_instance: Box<dyn StreamInstance + Send>);
    fn directory_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream_receiver: StreamReceiver,
    ) -> StreamSender<crate::DirectoryEntry>;
    fn has_pictures(&mut self) -> bool;
    fn image(&mut self, id: Uuid) -> Option<Vec<u8>>;
    fn image_with_size(
        &mut self,
        id: Uuid,
        witdh: i64,
        heigth: i64,
        stream_instance: Box<dyn StreamInstance + Send>,
    );
    fn image_with_size_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream_receiver: StreamReceiver,
    ) -> StreamSender<Vec<u8>>;
    fn remove_image(&mut self, id: Uuid);
}
