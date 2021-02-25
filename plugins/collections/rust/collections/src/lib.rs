pub use idl_types;
use idl_types::{idl_impl::PhotosInstance, idl_internal::*};

use std::io::{BufRead, BufReader};

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

                        let file_entry = Directory::Picture(Box::new(PictureEntry {
                            path: path.to_str().unwrap().to_owned(),
                            id: Uuid::new_v4(),
                            description: "".to_owned(),
                            name: file_name,
                            mime: tree_magic::from_filepath(&path).as_str().to_owned(),
                        }));

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

pub struct Photos {
    cur_dir: Option<DirectoryEntry>,
}

impl Photos {
    pub fn new() -> Self {
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

        Self { cur_dir: dir }
    }
}

impl PhotosInstance for Photos {
    fn directory(&mut self) -> Option<idl_types::DirectoryEntry> {
        self.cur_dir.as_ref().map(|v| v.clone())
    }

    fn image(&mut self, id: Uuid) -> Option<Vec<u8>> {
        find_image_by_id(id, self.cur_dir.as_ref().unwrap())
    }

    fn remove_image(&mut self, id: Uuid) -> Uuid {
        id
    }

    fn id(&mut self) -> Uuid {
        Uuid::new_v4()
    }
}
