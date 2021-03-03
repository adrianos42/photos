pub mod idl_impl;
pub use idl_internal;
pub use idl_internal::Uuid;
#[derive(Debug, Clone)]
pub struct PicturesDirectory {
    pub n_pictures: i64,
    pub directory: crate::DirectoryEntry,
}
#[derive(Debug, Clone)]
pub enum Directory {
    Picture(Box<PictureEntry>),
    Directory(Box<DirectoryEntry>),
}
#[derive(Debug, Clone)]
pub struct PictureEntry {
    pub id: Uuid,
    pub name: String,
    pub description: String,
    pub mime: String,
    pub width: i64,
    pub height: i64,
}
#[derive(Debug, Clone)]
pub struct DirectoryEntry {
    pub id: Uuid,
    pub name: String,
    pub items: Vec<crate::Directory>,
    pub thumbnail: Option<Uuid>,
    pub description: String,
}
