//! Turns `icon.png` into the window icon and, on Windows, the executable icon.

use std::env;
use std::fs::File;
use std::io::BufWriter;
use std::path::{Path, PathBuf};

const WINDOW_PX: u32 = 256;
const EXE_SIZES: [u32; 5] = [16, 32, 48, 64, 256];

/// Prepares icon assets during the application build and embeds Windows executable resources.
fn main() {
    let manifest = PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR"));
    let png_path = manifest.join("../logicview-ui/assets/icon.png");
    println!("cargo:rerun-if-changed={}", png_path.display());

    let source = image::open(&png_path)
        .unwrap_or_else(|err| panic!("read {}: {err}", png_path.display()))
        .into_rgba8();
    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR"));
    let window = resize(&source, WINDOW_PX);
    std::fs::write(out_dir.join("window-icon.rgba"), window.as_raw()).expect("write window icon");

    if env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        embed_exe_icon(&source, &out_dir);
    }
}

/// Creates an icon image at the size required by a desktop resource.
fn resize(source: &image::RgbaImage, size: u32) -> image::RgbaImage {
    image::imageops::resize(source, size, size, image::imageops::FilterType::Lanczos3)
}

/// Builds the Windows icon file and embeds it when the build host supports resource compilation.
fn embed_exe_icon(source: &image::RgbaImage, out_dir: &Path) {
    let ico_path = out_dir.join("logicview.ico");
    write_ico(source, &ico_path);
    #[cfg(windows)]
    {
        let mut res = winresource::WindowsResource::new();
        res.set_icon(ico_path.to_str().expect("icon path"));
        res.compile()
            .unwrap_or_else(|err| panic!("embed LogicView application icon: {err}"));
    }
    #[cfg(not(windows))]
    {
        let _ = ico_path;
    }
}

/// Packages the application artwork at multiple sizes for Windows shell and window displays.
fn write_ico(source: &image::RgbaImage, path: &Path) {
    let mut dir = ico::IconDir::new(ico::ResourceType::Icon);
    for size in EXE_SIZES {
        let resized = resize(source, size);
        let image = ico::IconImage::from_rgba_data(size, size, resized.into_raw());
        let entry = ico::IconDirEntry::encode(&image)
            .unwrap_or_else(|err| panic!("encode {size}px icon: {err}"));
        dir.add_entry(entry);
    }
    let file = File::create(path).unwrap_or_else(|err| panic!("create {}: {err}", path.display()));
    dir.write(&mut BufWriter::new(file))
        .unwrap_or_else(|err| panic!("write {}: {err}", path.display()));
}
