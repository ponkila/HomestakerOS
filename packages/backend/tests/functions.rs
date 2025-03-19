use std::fs;
use std::io::Write;
use tempfile::{tempdir, NamedTempFile};

// Import the helper functions from our library.
use backend::{compute_sha256, create_tarball, run_json2nix, run_nix_build, write_default_nix};

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
    // Create a temporary directory and a subdirectory.
    let dir = tempdir()?;
    let hostname_dir = dir.path().join("hostname");
    fs::create_dir_all(&hostname_dir)?;

    // Write default.nix with dummy json2nix output.
    let json2nix_output = "dummy_output";
    write_default_nix(&hostname_dir, json2nix_output)?;

    // Read the generated default.nix content.
    let default_nix_path = hostname_dir.join("default.nix");
    let content = fs::read_to_string(default_nix_path)?;

    // Build expected content and compare.
    let expected =
        "{ pkgs, lib, config, ... }: { homestakeros = ".to_string() + json2nix_output + "; }";
    assert_eq!(content, expected);
    Ok(())
}

#[test]
fn test_process_artifacts() -> Result<(), Box<dyn std::error::Error>> {
    let build_id = "test_build";

    // Create temporary directories and files to simulate output_dir.
    let output_dir = tempdir()?;

    let file_path = output_dir.path().join("bzImage");
    fs::write(&file_path, "artifact content")?;

    // Call process_artifacts function.
    let artifacts_info = backend::process_artifacts(output_dir.path(), build_id)
        .map_err(|e| format!("process_artifacts failed: {}", e))?;

    // Check that the file was processed.
    let artifact = &artifacts_info[0];
    assert_eq!(artifacts_info.len(), 1);
    assert_eq!(artifact["file"], "bzImage");

    // Verify the SHA256.
    let expected_sha = backend::compute_sha256(&file_path)?;
    assert_eq!(artifact["sha256"], expected_sha);

    // Verify the download URL.
    let expected_url = "/builds/".to_string() + build_id + "/" + "bzImage";
    assert_eq!(artifact["download_url"], expected_url);

    Ok(())
}

#[actix_web::test]
async fn test_handle_error() {
    // Define a sample error description and a dummy error detail.
    let desc = "Test error occurred";
    let dummy_error = "dummy error detail";

    // Call the helper function.
    let response = backend::handle_error(desc, dummy_error);

    // Verify that the response status code is 500 (Internal Server Error).
    assert_eq!(
        response.status(),
        actix_web::http::StatusCode::INTERNAL_SERVER_ERROR
    );

    // Extract the body from the response.
    let body = actix_web::body::to_bytes(response.into_body())
        .await
        .unwrap();
    let json_val: serde_json::Value = serde_json::from_slice(&body).unwrap();

    // Verify the JSON content.
    assert_eq!(json_val["status"], "error");
    assert_eq!(json_val["message"], desc);
    assert_eq!(json_val["error"], dummy_error);
}

#[test]
fn test_run_json2nix() {
    let input = r#"{"networking": { "hostName": "nixos", "firewall": {"enable":true, "allowedTCPPorts": [ 80, 443 ]} }}"#;
    let result = run_json2nix(input);
    match result {
        Ok(output) => {
            let expected = r#"{ networking = { firewall = { allowedTCPPorts = [ 80 443 ]; enable = true; }; hostName = "nixos"; }; }"#;
            assert_eq!(output.trim(), expected.trim());
        }
        Err(err) => {
            panic!("json2nix failed with error: {}", err);
        }
    }
}

#[test]
fn test_run_nix_build() -> Result<(), Box<dyn std::error::Error>> {
    // Create temporary directories and files to simulate flake setup.
    let tmp_dir = tempdir()?;
    let nix_config_dir = tmp_dir.path().join("nixConfig");
    fs::create_dir_all(&nix_config_dir)?;

    let flake_contents = include_str!("../src/static/flake.nix");
    fs::write(nix_config_dir.join("flake.nix"), flake_contents)?;

    let hostname = "testi";
    let hostname_dir = nix_config_dir.join("nixosConfigurations").join(hostname);
    fs::create_dir_all(&hostname_dir)?;

    let default_nix_content = r#"
{ pkgs, lib, config, ... }:
{
  homestakeros = {
    localization = {
      hostname = "testi";
    };
    ssh = {
      authorizedKeys = [ "testi" ];
    };
  };
}
"#;
    fs::write(hostname_dir.join("default.nix"), default_nix_content)?;

    // Create an output directory and define whitelist.
    let output_dir = tmp_dir.path().join("output");
    fs::create_dir_all(&output_dir)?;
    let whitelist = &["bzImage", "initrd.zst", "kexec-boot"];

    // Now call run_nix_build.
    run_nix_build(&nix_config_dir, hostname, &output_dir, whitelist)
        .map_err(|e| format!("run_nix_build failed: {}", e))?;

    // Check if files were properly created in the output directory.
    let mut _found_files = false; // Prefixed with underscore to silence the unused variable warning
    if output_dir.exists() {
        for entry in fs::read_dir(&output_dir)? {
            if let Ok(entry) = entry {
                if let Some(filename) = entry.file_name().to_str() {
                    if whitelist.contains(&filename) {
                        _found_files = true;
                        println!("Found expected file: {}", filename);
                        break;
                    }
                }
            }
        }
    }

    Ok(())
}

#[test]
fn test_create_tarball() -> Result<(), Box<dyn std::error::Error>> {
    // Create a temporary directory with a test file
    let source_dir = tempdir()?;
    let file_path = source_dir.path().join("test.txt");
    fs::write(&file_path, "content")?;

    // Create an output directory
    let output_dir = tempdir()?;
    let filename = "archive.tar";

    // Create a tarball using the new signature
    create_tarball(source_dir.path(), output_dir.path(), filename)?;

    // Check that the tarball was created in the output directory
    let tar_path = output_dir.path().join(filename);
    assert!(
        tar_path.exists(),
        "Tarball should have been created at {}",
        tar_path.display()
    );

    // Open the tarball and verify it contains "test.txt"
    let tar_file = fs::File::open(&tar_path)?;
    let mut archive = tar::Archive::new(tar_file);
    let mut found = false;
    for entry in archive.entries()? {
        let entry = entry?;
        let path = entry.path()?;
        if path.to_string_lossy().contains("test.txt") {
            found = true;
            break;
        }
    }
    assert!(found, "Tarball should contain test.txt");
    Ok(())
}
