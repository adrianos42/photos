pub mod idl_impl;
pub use idl_internal;
pub use idl_internal::Uuid;
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
    pub path: String,
    pub mime: String,
}
#[derive(Debug, Clone)]
pub struct DirectoryEntry {
    pub id: Uuid,
    pub items: Vec<crate::Directory>,
    pub thumbnail: Option<crate::PictureEntry>,
    pub description: String,
    pub name: String,
    pub path: String,
}
