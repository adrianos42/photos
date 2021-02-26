use idl_internal::{StreamInstance, StreamReceiver, StreamSender, Uuid};
pub trait PhotosInstance {
    fn directory(&mut self, stream_instance: Box<dyn StreamInstance + Send>);
    fn directory_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream_receiver: StreamReceiver,
    ) -> StreamSender<crate::DirectoryEntry>;
    fn image(&mut self, id: Uuid, stream_instance: Box<dyn StreamInstance + Send>);
    fn image_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream_receiver: StreamReceiver,
    ) -> StreamSender<Vec<u8>>;
    fn remove_image(&mut self, id: Uuid) -> Uuid;
    fn id(&mut self) -> Uuid;
}
