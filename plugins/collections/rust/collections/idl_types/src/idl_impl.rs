use idl_internal::{StreamInstance, StreamReceiver, StreamSender, Uuid};
pub trait PhotosInstance {
    fn directory(&mut self) -> Option<crate::DirectoryEntry>;
    fn image(&mut self, id: Uuid) -> Option<Vec<u8>>;
    fn remove_image(&mut self, id: Uuid) -> Uuid;
    fn id(&mut self) -> Uuid;
}