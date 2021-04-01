use bytes::{BufMut};
use crossbeam_channel::{internal::SelectHandle, Receiver, Sender};
pub use idl_types;
use idl_types::{idl_impl::PhotosInstance, idl_internal::*};

use std::{
    io::{BufReader, BufWriter,},
    sync::RwLock,
    time::{Duration, Instant},
};

use notify::{RecommendedWatcher, RecursiveMode, Watcher};

use idl_types::*;
use log::warn;
use std::collections::HashMap;
use std::fs::*;
use std::io::prelude::Read;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use systemd::{journal, sd_journal_log};

use image::{codecs::png, imageops::resize};
use image::{imageops::FilterType, io::Reader, ImageBuffer, ImageFormat};

enum DirectoryInstance {
    Directory {
        id: Uuid,
        entry: DirectoryEntry,
        path: PathBuf,
        items: HashMap<Uuid, DirectoryInstance>,
    },
    Picture {
        id: Uuid,
        entry: PictureEntry,
        path: PathBuf,
        thumbnail: Option<Vec<u8>>,
        // img: Reader<BufReader<File>>,
    },
}

impl DirectoryInstance {
    fn from_user_pics() -> anyhow::Result<(Uuid, DirectoryInstance)> {
        if let Some(user_dirs) = directories::UserDirs::new() {
            if let Some(pic_dir) = user_dirs.picture_dir() {
                return Self::visit_dirs(pic_dir);
            }
        }

        Err(anyhow::anyhow!(""))
    }

    fn user_pics_path() -> anyhow::Result<PathBuf> {
        if let Some(user_dirs) = directories::UserDirs::new() {
            if let Some(pic_dir) = user_dirs.picture_dir() {
                return Ok(pic_dir.to_path_buf());
            }
        }

        Err(anyhow::anyhow!(""))
    }

    fn visit_dirs(dir: &Path) -> anyhow::Result<(Uuid, DirectoryInstance)> {
        let mut n_dirs = HashMap::new();
        let mut n_items = Vec::new();

        let mut thumbnail_id = None;

        if dir.is_dir() {
            for entry in read_dir(dir)? {
                let entry = entry?;
                let path = entry.path();

                if path.is_dir() {
                    let (id, dir_entry) = Self::visit_dirs(&path)?;

                    match &dir_entry {
                        DirectoryInstance::Directory { items, entry, .. } => {
                            if items.len() > 0 {
                                n_items.push(Directory::Directory(Box::new(entry.clone())));
                                n_dirs.insert(id, dir_entry);
                            }
                        }
                        _ => {}
                    }
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

                            let id = Uuid::new_v4();
                            let mime = tree_magic::from_filepath(&path).as_str().to_owned();
                            thumbnail_id = Some(id);

                            let img = Reader::open(&path)?.with_guessed_format()?;

                            let (width, height) = img.into_dimensions()?;

                            let pic = PictureEntry {
                                id,
                                mime,
                                name: file_name,
                                description: "".to_owned(),
                                height: height as i64,
                                width: width as i64,
                            };

                            n_items.push(Directory::Picture(Box::new(pic.clone())));
                            n_dirs.insert(
                                id,
                                DirectoryInstance::Picture {
                                    id,
                                    path: path.to_path_buf(),
                                    entry: pic,
                                    thumbnail: None,
                                },
                            );
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

        let id = Uuid::new_v4();

        Ok((
            id,
            DirectoryInstance::Directory {
                id,
                path: dir.to_path_buf(),
                entry: DirectoryEntry {
                    id,
                    description: "".to_owned(),
                    name: directory_name,
                    thumbnail: thumbnail_id,
                    items: n_items,
                },
                items: n_dirs,
            },
        ))
    }

    fn all_pics_id(&self) -> Vec<Uuid> {
        let mut result = vec![];

        match self {
            DirectoryInstance::Picture { id, .. } => result.push(id.clone()),
            DirectoryInstance::Directory { items, .. } => {
                for item in items.values() {
                    result.append(&mut item.all_pics_id());
                }
            }
        }

        result
    }

    fn find_from_path<'a>(&'a self, fpath: &Path) -> anyhow::Result<&'a Self> {
        match self {
            DirectoryInstance::Directory { items, path, .. } => {
                if fpath == path {
                    return Ok(self);
                }

                for value in items.values() {
                    if let Ok(res) = value.find_from_path(fpath) {
                        return Ok(res);
                    }
                }
            }
            DirectoryInstance::Picture { path, .. } => {
                if fpath == path {
                    return Ok(self);
                }
            }
        }

        Err(anyhow::anyhow!(""))
    }

    fn find_parent_from_path<'a>(
        &'a self,
        parent: Option<&'a Self>,
        fpath: &Path,
    ) -> anyhow::Result<&'a Self> {
        match self {
            DirectoryInstance::Directory { path, items, .. } => {
                if fpath == path {
                    if let Some(parent) = parent {
                        return Ok(parent);
                    }
                } else {
                    for value in items.values() {
                        if let Ok(res) = value.find_parent_from_path(Some(self), fpath) {
                            return Ok(res);
                        }
                    }
                }
            }
            DirectoryInstance::Picture { path, .. } => {
                if let Some(parent) = parent {
                    if fpath == path {
                        return Ok(parent);
                    }
                }
            }
        }

        Err(anyhow::anyhow!(""))
    }

    fn item_path(&self) -> PathBuf {
        match self {
            DirectoryInstance::Directory { path, .. } => path.clone(),
            DirectoryInstance::Picture { path, .. } => path.clone(),
        }
    }

    fn find_image(&self, picture_id: Uuid) -> anyhow::Result<Vec<u8>> {
        match self {
            DirectoryInstance::Directory { items, .. } => {
                for item in items.values() {
                    match item {
                        DirectoryInstance::Picture { id, path, .. } => {
                            if picture_id == *id {
                                let mut file = File::open(&path)?;

                                let mut buffer = vec![];
                                file.read_to_end(&mut buffer)?;

                                if buffer.len() > 0 {
                                    return Ok(buffer);
                                }
                            }
                        }
                        sw => {
                            if let Ok(value) = sw.find_image(picture_id) {
                                return Ok(value);
                            }
                        }
                    }
                }
            }
            _ => {}
        }

        Err(anyhow::anyhow!(""))
    }

    fn find_picture(&self, picture_id: Uuid) -> anyhow::Result<PictureEntry> {
        match self {
            DirectoryInstance::Directory { items, .. } => {
                for item in items.values() {
                    match item {
                        DirectoryInstance::Picture { id, entry, .. } => {
                            if picture_id == *id {
                                return Ok(entry.clone());
                            }
                        }
                        sw => {
                            if let Ok(value) = sw.find_picture(picture_id) {
                                return Ok(value);
                            }
                        }
                    }
                }
            }
            _ => {}
        }

        Err(anyhow::anyhow!(""))
    }

    fn has_any_picture(&self) -> bool {
        match self {
            DirectoryInstance::Directory { items, .. } => {
                for item in items.values() {
                    if item.has_any_picture() {
                        return true;
                    }
                }

                false
            }
            DirectoryInstance::Picture { .. } => true,
        }
    }

    fn count_pictures(&self) -> i64 {
        let mut result = 0;
        match self {
            DirectoryInstance::Directory { items, .. } => {
                for item in items.values() {
                    result += item.count_pictures();
                }
            }
            DirectoryInstance::Picture { .. } => result += 1,
        }
        result
    }

    fn find_instance(&self, fid: Uuid) -> anyhow::Result<&DirectoryInstance> {
        match self {
            DirectoryInstance::Directory { id, items, .. } => {
                if fid == *id {
                    return Ok(self);
                }

                for item in items.values() {
                    if let Ok(value) = item.find_instance(fid) {
                        return Ok(value);
                    }
                }
            }
            DirectoryInstance::Picture { id, .. } => {
                if fid == *id {
                    return Ok(self);
                }
            }
        }

        Err(anyhow::anyhow!(""))
    }

    fn find_instance_mut(&mut self, fid: Uuid) -> anyhow::Result<&mut DirectoryInstance> {
        match self {
            DirectoryInstance::Directory { id, .. } => {
                if fid == *id {
                    return Ok(self);
                }
            }
            DirectoryInstance::Picture { id, .. } => {
                if fid == *id {
                    return Ok(self);
                }
            }
        }

        match self {
            DirectoryInstance::Directory { items, .. } => {
                for item in items.values_mut() {
                    if let Ok(value) = item.find_instance_mut(fid) {
                        return Ok(value);
                    }
                }
            }
            _ => {}
        }

        Err(anyhow::anyhow!(""))
    }

    fn set_thumbnail(&mut self, picture_id: Uuid, new_thumbnail: Vec<u8>) -> anyhow::Result<()> {
        match self.find_instance_mut(picture_id)? {
            DirectoryInstance::Picture { thumbnail, .. } => {
                thumbnail.replace(new_thumbnail);
            }
            _ => {}
        }

        Ok(())
    }

    fn get_thumbnail(&self, picture_id: Uuid) -> anyhow::Result<Vec<u8>> {
        match self.find_instance(picture_id)? {
            DirectoryInstance::Picture { thumbnail, .. } => {
                if let Some(thumbnail) = thumbnail.as_ref() {
                    return Ok(thumbnail.clone());
                }
            }
            _ => {}
        }

        Err(anyhow::anyhow!("Could not find thumbnail"))
    }

    fn find_directory(&self, dir_id: Uuid) -> anyhow::Result<DirectoryEntry> {
        match self {
            DirectoryInstance::Directory {
                items, id, entry, ..
            } => {
                if dir_id == *id {
                    return Ok(entry.clone());
                }

                for item in items.values() {
                    if let Ok(value) = item.find_directory(dir_id) {
                        return Ok(value);
                    }
                }
            }
            _ => {}
        }

        Err(anyhow::anyhow!(""))
    }
}

#[derive(Default)]
pub struct Photos {
    pictures_directory_instances: Arc<RwLock<Option<DirectoryInstance>>>,
    directory_entries: Arc<RwLock<HashMap<i64, (Sender<(bool, Option<Uuid>)>, Uuid)>>>,
    thumbnail_streams: Arc<RwLock<HashMap<i64, Vec<u8>>>>,
    thumbnail_size: Arc<RwLock<(i64, i64)>>,
}

impl Photos {
    pub fn new() -> Self {
        let result = Self::default();
        *result.thumbnail_size.write().unwrap() = (500, 500);
        result
    }
}

impl PhotosInstance for Photos {
    fn pictures_directory(&mut self, stream_instance: Box<dyn StreamInstance + Send>) {
        let update_context = self.pictures_directory_instances.clone();
        let directories_context = self.directory_entries.clone();

        //journal::print(6, &format!("Directory get"));

        // if update_context.read().unwrap().as_ref().is_some() {
        //     stream_instance.wake_client();
        //     return;
        // }

        let (width, height) = self.thumbnail_size.read().unwrap().clone();

        std::thread::spawn(move || {
            let (tx, rx) = crossbeam_channel::unbounded();

            let mut watcher: RecommendedWatcher = Watcher::new_immediate(move |res| {
                tx.send(res).unwrap();
            })
            .unwrap();

            match DirectoryInstance::user_pics_path() {
                Ok(path) => {
                    watcher.watch(&path, RecursiveMode::Recursive).unwrap();
                }
                _ => {
                    panic!();
                }
            }

            let update_root_dir = move || {
                if let Ok((_, directory)) = DirectoryInstance::from_user_pics() {
                    //journal::print(6, &format!("Directory changed sent"));
                    update_context.write().unwrap().replace(directory);

                    // for (tx, _) in pictures_context.read().unwrap().values() {
                    //     let _ = tx.try_send((true, None));
                    // }
                    // for (tx, _) in directories_context.read().unwrap().values() {
                    //     let _ = tx.try_send((true, None));
                    // }

                    stream_instance.wake_client();
                }
            };

            update_root_dir();

            // for event in rx.iter() {
            //     journal::print(6, &format!("Directory changed"));
            //     if let Ok(event) = event {
            //         match event.kind {
            //             notify::EventKind::Modify(modify) => match modify {
            //                 notify::event::ModifyKind::Any => {}
            //                 notify::event::ModifyKind::Data(_) => {}
            //                 notify::event::ModifyKind::Metadata(_) => {}
            //                 notify::event::ModifyKind::Name(_) => {
            //                     journal::print(6, &format!("Directory changed name"));
            //                     update_root_dir();
            //                 }
            //                 notify::event::ModifyKind::Other => {}
            //             },
            //             notify::EventKind::Create(_) => update_root_dir(),
            //             notify::EventKind::Remove(_) => update_root_dir(),
            //             _ => {}
            //         }
            //     }
            // }
        });
    }

    fn pictures_directory_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream: StreamReceiver,
    ) -> StreamSender<PicturesDirectory> {
        let context = self.pictures_directory_instances.clone();

        //journal::print(6, &format!("Sending request changed"));

        match stream {
            StreamReceiver::Request => {
                //let handle = stream_instance.get_id();
                if let Some(directory) = context.read().unwrap().as_ref() {
                    match directory {
                        DirectoryInstance::Directory { entry, .. } => {
                            //journal::print(6, &format!("Sending changed"));
                            return StreamSender::Value(PicturesDirectory {
                                directory: entry.clone(),
                                n_pictures: directory.count_pictures(),
                            });
                        }
                        _ => {}
                    }
                }

                StreamSender::Done
            }
            StreamReceiver::Close => {
                let handle = stream_instance.get_id();
                //journal::print(6, &format!("Stream closed, id: {}", handle));

                StreamSender::Ok
            }
            _ => StreamSender::Ok,
        }
    }

    fn directory(&mut self, id: Uuid, stream_instance: Box<dyn StreamInstance + Send>) {
        let context = self.directory_entries.clone();
        let pics_context = self.pictures_directory_instances.clone();

        std::thread::spawn(move || {
            let (tx, rx) = crossbeam_channel::unbounded();
            let handle = stream_instance.get_id();

            if context.write().unwrap().insert(handle, (tx, id)).is_some() {
                //                journal::print(3, &format!("Error in stream creation, id: {}", handle));
            }

            stream_instance.wake_client();

            // for (cancel, id) in rx.iter() {
            //     if cancel {
            //         return;
            //     }
            //     let (tx, _) = context.write().unwrap().remove(&handle).unwrap();
            //     context.write().unwrap().insert(handle, (tx, id.unwrap()));
            //     stream_instance.wake_client();
            // }
        });
    }

    fn directory_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream: StreamReceiver,
    ) -> StreamSender<DirectoryEntry> {
        let pics_context = self.pictures_directory_instances.clone();

        match stream {
            StreamReceiver::Request => {
                let handle = stream_instance.get_id();
                //journal::print(6, &format!("Image request, id: {}", handle));

                match self.directory_entries.clone().write().unwrap().get(&handle) {
                    Some((_, id)) => {
                        if let Some(directory) = pics_context.read().unwrap().as_ref() {
                            match directory.find_directory(*id) {
                                Ok(dir) => return StreamSender::Value(dir),
                                Err(_) => {}
                            }
                        }
                    }
                    None => {
                        //journal::print(3, &format!("Error getting picture, id: {}", handle));
                    }
                }

                StreamSender::Done
            }
            StreamReceiver::Close => {
                let handle = stream_instance.get_id();
                //journal::print(6, &format!("Stream closed, id: {}", handle));

                StreamSender::Ok
            }
            _ => StreamSender::Ok,
        }
    }

    fn image(&mut self, id: Uuid) -> Option<Vec<u8>> {
        self.pictures_directory_instances
            .read()
            .unwrap()
            .as_ref()
            .and_then(|v| v.find_image(id).ok())
    }

    fn image_with_size(
        &mut self,
        id: Uuid,
        width: i64,
        height: i64,
        stream_instance: Box<dyn StreamInstance + Send>,
    ) {
        todo!()
    }

    fn image_with_size_stream(
        &mut self,
        stream_instance: Box<dyn StreamInstance + Send>,
        stream_receiver: StreamReceiver,
    ) -> StreamSender<Vec<u8>> {
        todo!()
    }

    fn remove_image(&mut self, _id: Uuid) {}

    fn has_pictures(&mut self) -> bool {
        match self
            .pictures_directory_instances
            .clone()
            .read()
            .unwrap()
            .as_ref()
        {
            Some(value) => value.has_any_picture(),
            None => false,
        }
    }
}

fn set_instances_thumbnail(
    instance: Arc<RwLock<Option<DirectoryInstance>>>,
    width: i64,
    height: i64,
) {
    let ids = match instance.read().unwrap().as_ref() {
        Some(ins) => ins.all_pics_id(),
        None => return,
    };

    for id in ids {
        let now = Instant::now();
        let path = instance.read().unwrap().as_ref().unwrap().item_path();
        let image = get_thumbnail_image(&path, width, height);

        let mut stt = instance.write().unwrap();
        let ins = stt.as_mut().unwrap();
        let _ = ins.set_thumbnail(id, image);
    }
}



fn get_thumbnail_image(path: &Path, width: i64, height: i64) -> Vec<u8> {
    let reader = Reader::open(&path)
        .expect("opening reader")
        .with_guessed_format()
        .expect("guessed format");

    let img = reader.decode().expect("decoding");

    let mut writer = bytes::BytesMut::with_capacity(0x2000);
    let mut output_writer = writer.writer();
    img.thumbnail(width as u32, height as u32)
        .write_to(&mut writer, ImageFormat::Png)
        .expect("Writing to buffer");
    writer
}
