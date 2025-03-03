use std::fs;
use std::io::Write;
use tempfile::{tempdir, NamedTempFile};

// Import the helper functions from our library.
use backend::{compute_sha256, write_default_nix};

#[test]
fn test_compute_sha256() -> Result<(), Box<dyn std::error::Error>> {
    // Create a temporary file with known content.
    let mut temp = NamedTempFile::new()?;
    write!(temp, "hello world")?;
    let hash = compute_sha256(temp.path())?;

    // SHA256("hello world") is:
    let expected = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9";
    assert_eq!(hash, expected);
    Ok(())
}

#[test]
fn test_write_default_nix() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let hostname_dir = dir.path().join("hostname");
    fs::create_dir_all(&hostname_dir)?;

    let json2nix_output = "dummy_output";
    write_default_nix(&hostname_dir, json2nix_output)?;

    let default_nix_path = hostname_dir.join("default.nix");
    let content = fs::read_to_string(default_nix_path)?;
    let expected =
        "{ pkgs, lib, config, ... }: { homestakeros = ".to_string() + json2nix_output + "; }";

    assert_eq!(content, expected);
    Ok(())
}

#[test]
fn test_process_artifacts() -> Result<(), Box<dyn std::error::Error>> {
    let whitelist = ["bzImage", "initrd.zst", "kexec-boot"];
    let build_id = "test_build";

    // Create temporary directories and files to simulate out_link.
    let out_dir = tempdir()?;
    let final_dir = tempdir()?;

    let whitelisted_path = out_dir.path().join("bzImage");
    fs::write(&whitelisted_path, "artifact content")?;

    let non_whitelisted_path = out_dir.path().join("ignored.txt");
    fs::write(&non_whitelisted_path, "should be ignored")?;

    // Call process_artifacts function.
    let artifacts_info =
        backend::process_artifacts(out_dir.path(), final_dir.path(), build_id, &whitelist)
            .map_err(|e| format!("process_artifacts failed: {}", e))?;

    // Check that only the bzImage got processed.
    let artifact = &artifacts_info[0];
    assert_eq!(artifacts_info.len(), 1);
    assert_eq!(artifact["file"], "bzImage");

    let copied_file_path = final_dir.path().join("bzImage");
    assert!(copied_file_path.exists());

    // Verify the SHA256.
    let expected_sha = backend::compute_sha256(&copied_file_path)?;
    assert_eq!(artifact["sha256"], expected_sha);

    // Verify the download URL.
    let expected_url = "/builds/".to_string() + build_id + "/" + "bzImage";
    assert_eq!(artifact["download_url"], expected_url);

    Ok(())
}
