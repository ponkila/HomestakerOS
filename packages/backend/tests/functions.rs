use std::fs;
use std::io::Write;
use tempfile::{tempdir, NamedTempFile};

// Import the helper functions from our library.
use backend::{compute_sha256, create_tarball, run_json2nix, run_nix_build, write_default_nix};

#[test]
fn test_compute_sha256() {
    // Create a temporary file with known content.
    let mut temp = NamedTempFile::new().unwrap();
    write!(temp, "hello world").unwrap();
    let hash = compute_sha256(temp.path()).unwrap();

    // SHA256("hello world") is:
    let expected = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9";
    assert_eq!(hash, expected);
}

#[test]
fn test_create_tarball() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("test.txt");
    fs::write(&file_path, "content").unwrap();

    // Create a separate temporary directory for the tar file.
    let tar_dir = tempdir().unwrap();
    let tar_path = tar_dir.path().join("archive.tar");

    // Create a tarball from the source directory.
    create_tarball(dir.path(), "testdir", &tar_path).unwrap();

    // Open the tarball and verify it contains "test.txt".
    let tar_file = fs::File::open(&tar_path).unwrap();
    let mut archive = tar::Archive::new(tar_file);
    let mut found = false;
    for entry in archive.entries().unwrap() {
        let entry = entry.unwrap();
        let path = entry.path().unwrap();
        if path.to_string_lossy().contains("test.txt") {
            found = true;
            break;
        }
    }
    assert!(found, "Tarball should contain test.txt");
}

#[test]
fn test_write_default_nix() {
    let dir = tempdir().unwrap();
    let hostname_dir = dir.path().join("hostname");
    fs::create_dir_all(&hostname_dir).unwrap();
    let json2nix_output = "dummy_output";
    write_default_nix(&hostname_dir, json2nix_output).unwrap();
    let default_nix_path = hostname_dir.join("default.nix");
    let content = fs::read_to_string(default_nix_path).unwrap();
    let expected = format!(
        "{{ pkgs, lib, config, ... }}: {{ homestakeros = {}; }}",
        json2nix_output
    );
    assert_eq!(content, expected);
}
