pub use idl_types;
use idl_types::{idl_impl::PhotosInstance, idl_internal::*};

use std::{sync::RwLock, time::Duration};

use notify::{RecommendedWatcher, RecursiveMode, Watcher};

use idl_types::*;
use std::collections::HashMap;
use std::fs::*;
use std::io::prelude::Read;
use std::path::{Path, PathBuf};
use std::sync::Arc;

// #[derive(Clone)]
// enum Directory {
//     DirectoryEntry {
//         path: PathBuf,
//         id: Uuid,
//         items: Vec<Directory>,
//     },
//     FileEntry {
//         path: PathBuf,
//         id: Uuid,
//     },
// }

fn visit_dirs(dir: &Path) -> Result<Directory, std::io::Error> {
    let mut n_dirs = Vec::new();

    let mut pic_entry = None;

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
                        let file_name = match path.file_name() {
                            Some(name) => name
                                .to_str()
                                .expect("Error converting directory name.")
                                .to_owned(),
                            None => panic!("Directory must have a name."),
                        };

                        let pic = PictureEntry {
                            path: path.to_str().unwrap().to_owned(),
                            id: Uuid::new_v4(),
                            description: "".to_owned(),
                            name: file_name,
                            mime: tree_magic::from_filepath(&path).as_str().to_owned(),
                        };

                        let file_entry = Directory::Picture(Box::new(pic.clone()));

                        pic_entry = Some(pic);
                        n_dirs.push(file_entry);
                    }
                    _ => {}
                }
            }
        }
    }

    let directory_name = match dir.file_name() {
        Some(name) => name
            .to_str()
            .expect("Error converting directory name.")
            .to_owned(),
        None => panic!("Directory must have a name."),
    };

    Ok(Directory::Directory(Box::new(DirectoryEntry {
        items: n_dirs,
        id: Uuid::new_v4(),
        path: dir.to_str().unwrap().to_owned(),
        description: "".to_owned(),
        thumbnail: pic_entry,
        name: directory_name,
    })))
}

fn find_image_by_id(img_id: Uuid, dir: &DirectoryEntry) -> Option<Vec<u8>> {
    for item in dir.items.iter() {
        match item {
            Directory::Directory(value) => {
                if let Some(image) = find_image_by_id(img_id, value) {
                    return Some(image);
                }
            }
            Directory::Picture(pic) => {
                if img_id == pic.id {
                    let mut file = File::open(Path::new(pic.path.as_str())).unwrap();

                    let mut buffer = vec![];
                    file.read_to_end(&mut buffer).unwrap();

                    if buffer.len() > 0 {
                        return Some(buffer);
                    }
                }
            }
        }
    }

    None
}

fn delete_image_by_id(img_id: Uuid, dir: &mut Directory) -> bool {
    // if let Directory::DirectoryEntry { items, .. } = dir {
    //     for (index, item) in items.iter_mut().enumerate() {
    //         match item {
    //             Directory::DirectoryEntry { .. } => {
    //                 if delete_image_by_id(img_id, item) {
    //                     return true;
    //                 }
    //             }
    //             Directory::FileEntry { ref id, path, .. } => {
    //                 if img_id == *id {
    //                     if let Err(_err) = remove_file(path) {
    //                         return true;
    //                     }

    //                     items.remove(index);

    //                     return true;
    //                 }
    //             }
    //         }
    //     }
    // };

    false
}

#[derive(Debug, Default)]
pub struct Photos {
    directory_instances: Arc<RwLock<Option<DirectoryEntry>>>,
    image_instances: Arc<RwLock<HashMap<i64, Vec<u8>>>>,
}

impl Photos {
    pub fn new() -> Self {
        Self::default()
    }
}

fn get_pics_dir() -> Option<DirectoryEntry> {
    let mut dir = None;

    if let Some(user_dirs) = directories::UserDirs::new() {
        if let Some(pic_dir) = user_dirs.picture_dir() {
            match visit_dirs(pic_dir) {
                Ok(directory) => match directory {
                    Directory::Directory(value) => {
                        dir = Some(value.as_ref().clone());
                    }
                    _ => {}
                },
                _ => {}
            }
        }
    }

    dir
}

impl PhotosInstance for Photos {
    fn remove_image(&mut self, id: Uuid) -> Uuid {
        id
    }

    fn id(&mut self) -> Uuid {
        Uuid::new_v4()
    }

    fn directory(&mut self, stream_instance: Box<dyn StreamInstance + Send>) {
        let context = self.directory_instances.clone();

        match self.directory_instances.read().unwrap().as_ref() {
            Some(_) => {
                stream_instance.wake_client();
            }
            None => {
                std::thread::spawn(move || {
                    let (tx, rx) = crossbeam_channel::unbounded();
                    let mut watcher: RecommendedWatcher = Watcher::new_immediate(move |res| {
                        tx.send(res).unwrap();
                    })
                    .unwrap();

                    if let Some(directory) = get_pics_dir() {
                        watcher.watch(Path::new(&directory.path), RecursiveMode::Recursive).unwrap();
                        context.write().unwrap().replace(directory);
                    }

                    stream_instance.wake_client();

                    for event in rx.iter() {
                        if let Some(directory) = get_pics_dir() {
                            context.write().unwrap().replace(directory);
                        }
                    }
                });
            }
        }
    }

    fn directory_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream: StreamReceiver,
    ) -> StreamSender<DirectoryEntry> {
        let context = self.directory_instances.clone();

        match stream {
            StreamReceiver::Request => {
                let handle = stream_instance.get_id();
                match context.read().unwrap().as_ref() {
                    Some(value) => return StreamSender::Value(value.clone()),
                    None => {}
                }

                StreamSender::Done
            }
            _ => StreamSender::Ok,
        }
    }

    fn image(&mut self, id: Uuid, stream_instance: Box<dyn StreamInstance + Send>) {
        let context = self.image_instances.clone();
        let dir_context = self.directory_instances.clone();

        std::thread::spawn(move || {
            let handle = stream_instance.get_id();

            if let Some(directory) = dir_context.read().unwrap().as_ref() {
                if let Some(image) = find_image_by_id(id, directory) {
                    if context.write().unwrap().insert(handle, image).is_some() {
                        panic!();
                    }
                    stream_instance.wake_client();
                }
            }
        });
    }

    fn image_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream: StreamReceiver,
    ) -> StreamSender<Vec<u8>> {
        match stream {
            StreamReceiver::Request => {
                let handle = stream_instance.get_id();
                match self
                    .image_instances
                    .clone()
                    .write()
                    .unwrap()
                    .remove(&handle)
                {
                    Some(value) => return StreamSender::Value(value),
                    None => {}
                }

                StreamSender::Done
            }
            _ => StreamSender::Ok,
        }
    }
}
