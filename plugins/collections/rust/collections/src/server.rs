use std::collections::HashMap;
//use std::hash::{Hash, Hasher};
//use std::pin::Pin;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use futures::StreamExt;
use std::fs::*;
use tokio::io::{self, AsyncReadExt};
use tokio::sync::{mpsc, Mutex, Notify};
use tonic::transport::Server;
use tonic::{Code, Request, Response, Status};

use std::io::prelude::Read;
use std::io::{BufRead, BufReader};

use prost::Message;

use uuid::Uuid;

use gallery::gallery_server::{Gallery, GalleryServer};
use gallery::*;

pub mod gallery {
    tonic::include_proto!("gallery");
}

mod data;


fn get_uuid() -> String {
    Uuid::new_v4().to_simple().to_string()
}

fn create_any<T: Message>(value: T, name: &str) -> prost_types::Any {
    let mut value_packed = Vec::with_capacity(value.encoded_len());
    value.encode(&mut value_packed).unwrap();

    prost_types::Any {
        type_url: "type.googleapis.com/".to_string() + name,
        value: value_packed,
    }
}

fn visit_dirs(dir: &Path) -> Result<Directory, io::Error> {
    let mut n_dirs = Vec::new();

    if dir.is_dir() {
        for entry in read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let dir_entry = visit_dirs(&path)?;
                n_dirs.push(dir_entry);
            } else if path.is_file() {
                match tree_magic::from_filepath(&path).as_str() {
                    "image/webp" | "image/jpeg" | "image/png" | "image/gif" => {
                        let file_entry = Directory::FileEntry {
                            path: path,
                            id: get_uuid(),
                        };

                        n_dirs.push(file_entry);
                    }
                    _ => {}
                }
            }
        }
    }

    Ok(Directory::DirectoryEntry {
        items: n_dirs,
        id: get_uuid(),
        path: dir.to_owned(),
    })
}

fn find_image_by_id(dir: &Directory, img_id: &str) -> Option<Vec<u8>> {
    if let Directory::DirectoryEntry { items, .. } = dir {
        for item in items.iter() {
            match item {
                Directory::DirectoryEntry { .. } => {
                    if let Some(image) = find_image_by_id(item, img_id) {
                        return Some(image);
                    }
                }
                Directory::FileEntry { ref id, path, .. } => {
                    if img_id == id {
                        let mut file = File::open(path).unwrap();

                        let mut buffer = vec![];
                        file.read_to_end(&mut buffer).unwrap();

                        if buffer.len() > 0 {
                            return Some(buffer);
                        }
                    }
                }
            }
        }
    };

    None
}

fn delete_image_by_id(dir: &mut Directory, img_id: &str) -> bool {
    if let Directory::DirectoryEntry { items, .. } = dir {
        for (index, item) in items.iter_mut().enumerate() {
            match item {
                Directory::DirectoryEntry { .. } => {
                    if delete_image_by_id(item, img_id) {
                        return true;
                    }
                }
                Directory::FileEntry { ref id, path, .. } => {
                    if img_id == id {
                        if let Err(_err) = remove_file(path) {
                            return true;
                        }

                        items.remove(index);

                        return true;
                    }
                }
            }
        }
    };

    false
}

fn generate_folder_items(dir_item: &Directory) -> Option<DirectoryEntry> {
    let mut anys = vec![];

    // Item must be a directory
    match dir_item {
        Directory::DirectoryEntry {
            id, items, path, ..
        } => {
            for item in items.iter() {
                let any = match item {
                    Directory::DirectoryEntry { .. } => {
                        let value = generate_folder_items(item).unwrap();

                        create_any(value, "gallery.DirectoryEntry")
                    }
                    Directory::FileEntry { id, path, .. } => {
                        let file_name = match path.file_name() {
                            Some(name) => name
                                .to_str()
                                .expect("Error converting directory name.")
                                .to_owned(),
                            None => panic!("Directory must have a name."),
                        };

                        let value = PictureEntry {
                            picture_id: id.to_owned(),
                            description: "".to_string(),
                            name: file_name,
                        };

                        create_any(value, "gallery.PictureEntry")
                    }
                };

                anys.push(any);
            }

            let directory_name = match path.file_name() {
                Some(name) => name
                    .to_str()
                    .expect("Error converting directory name.")
                    .to_owned(),
                None => panic!("Directory must have a name."),
            };

            return Some(DirectoryEntry {
                directory_id: id.to_owned(),
                description: "".to_string(),
                items: anys,
                name: directory_name,
            });
        }
        Directory::FileEntry { .. } => {
            return None;
        }
    }
}

#[derive(Default)]
pub struct GalleryService {
    collections_state: Arc<Mutex<HashMap<String, PathBuf>>>,
    directories_state: Arc<Mutex<HashMap<String, Directory>>>,
}

#[tonic::async_trait]
impl Gallery for GalleryService {
    async fn get_pictures_collection(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Collection>, Status> {
        let state = self.collections_state.clone();
        let mut collections = state.lock().await;

        if let Some(user_dirs) = directories::UserDirs::new() {
            let pic_dir = user_dirs.picture_dir().unwrap();

            for (key, val) in collections.iter() {
                if val == pic_dir {
                    let collection = Collection {
                        collection_id: key.to_owned(),
                    };
                    return Ok(Response::new(collection));
                }
            }

            let id = get_uuid();

            collections.insert(id.to_owned(), pic_dir.to_owned());

            let collection = Collection { collection_id: id };
            return Ok(Response::new(collection));
        }

        Err(Status::new(Code::NotFound, "Coudn't find folder."))
    }

    //  type GetCollectionDirectoryStream = mpsc::Receiver<Result<DirectoryEntry, Status>>;

    async fn get_collection_directory(
        &self,
        request: Request<Collection>,
    ) -> Result<Response<DirectoryEntry>, Status> {
        let collections_state = self.collections_state.clone();
        let directories_state = self.directories_state.clone();

        let collections = collections_state.lock().await;
        let mut dirs = directories_state.lock().await;

        let id = request.get_ref().collection_id.as_str();

        match collections.get(id) {
            Some(path) => {
                let dir = match dirs.get(id) {
                    Some(dir) => dir,
                    None => {
                        let dir = visit_dirs(path)?;
                        dirs.insert(id.to_owned(), dir);
                        dirs.get(id).unwrap()
                    }
                };

                return Ok(Response::new(generate_folder_items(dir).unwrap()));
            }
            None => return Err(Status::new(Code::NotFound, "Collection does not exist.")),
        }
    }

    type GetImageStream = mpsc::Receiver<Result<Image, Status>>;

    async fn get_image(
        &self,
        request: Request<ImageRequest>,
    ) -> Result<Response<Self::GetImageStream>, Status> {
        let (mut tx, rx) = mpsc::channel(4);

        let directories_state = self.directories_state.clone();

        tokio::task::spawn(async move {
            let dirs = directories_state.lock().await;

            let id = request.get_ref().collection_id.as_str();

            match dirs.get(id) {
                Some(dir) => {
                    let img_id = request.get_ref().image_id.as_str();

                    match find_image_by_id(dir, img_id) {
                        Some(image) => {
                            let res = Image { data: image };
                            if let Err(_err) = tx.send(Ok(res)).await {}
                        }
                        None => {
                            if let Err(_err) = tx
                                .send(Err(Status::new(Code::NotFound, "Image not found")))
                                .await
                            {}
                        }
                    }
                }
                None => {
                    if let Err(_err) = tx
                        .send(Err(Status::new(
                            Code::NotFound,
                            "Collection does not exist.",
                        )))
                        .await
                    {}
                }
            }
        });

        Ok(Response::new(rx))
    }

    async fn remove_image(
        &self,
        request: Request<ImageRequest>,
    ) -> Result<Response<Empty>, Status> {
        let directories_state = self.directories_state.clone();

        let mut dirs = directories_state.lock().await;

        let id = request.get_ref().collection_id.as_str();

        match dirs.get_mut(id) {
            Some(dir) => {
                let img_id = request.get_ref().image_id.as_str();

                delete_image_by_id(dir, img_id);
            }
            None => return Err(Status::new(Code::NotFound, "Collection does not exist.")),
        }

        Ok(Response::new(Empty {}))
    }
}

fn test_dirs() {
    if let Some(user_dirs) = directories::UserDirs::new() {
        let pic_dir = user_dirs.picture_dir().unwrap();

        visit_dirs(pic_dir);
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    //test_dirs();

    //return Ok(());

    let gallery = GalleryService {
        collections_state: Arc::new(Mutex::new(HashMap::new())),
        directories_state: Arc::new(Mutex::new(HashMap::new())),
    };

    let svc = GalleryServer::new(gallery);

    let addr = "127.0.0.1:50052".parse().unwrap();

    Server::builder().add_service(svc).serve(addr).await?;

    Ok(())
}
