pub mod schema_types;
pub mod workspace;

use actix_web::HttpResponse;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::fs;
use std::io::{BufReader, Read, Write};
use std::path::Path;
use std::process::{Command as StdCommand, Stdio};

/// Runs the `json2nix` command by piping in the JSON string and returns the command's stdout.
pub fn run_json2nix(json_str: &str) -> Result<String, String> {
    let mut child = StdCommand::new("json2nix")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to spawn json2nix process: {:?}", e))?;

    {
        let stdin = child
            .stdin
            .as_mut()
            .ok_or_else(|| "Failed to open stdin for json2nix".to_string())?;
        stdin
            .write_all(json_str.as_bytes())
            .map_err(|e| format!("Failed to write to stdin of json2nix: {:?}", e))?;
    }
    let output = child
        .wait_with_output()
        .map_err(|e| format!("Command execution failed: {:?}", e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(stderr);
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Writes the default.nix file with the provided json2nix output.
pub fn write_default_nix(hostname_dir: &Path, json2nix_output: &str) -> std::io::Result<()> {
    let nix_boilerplate =
        String::from("{ pkgs, lib, config, ... }: { homestakeros = ") + json2nix_output + "; }";
    let default_nix_path = hostname_dir.join("default.nix");
    fs::write(default_nix_path, nix_boilerplate.as_bytes())
}

/// Runs the `nix build` command and returns an error string if it fails.
pub fn run_nix_build(nix_config_dir: &Path, hostname: &str, out_link: &Path) -> Result<(), String> {
    let nix_config_dir_str = nix_config_dir.display().to_string();
    let build_arg = format!(
        "path:{}#nixosConfigurations.{}.config.system.build.kexecTree",
        nix_config_dir_str, hostname
    );
    let output = StdCommand::new("nix")
        .arg("build")
        .arg(build_arg)
        .arg("--out-link")
        .arg(out_link)
        .arg("--extra-experimental-features")
        .arg("nix-command")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| format!("Failed to execute nix build: {:?}", e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(stderr);
    }
    println!(
        "Nix build stdout: {}",
        String::from_utf8_lossy(&output.stdout)
    );
    println!(
        "Nix build stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    Ok(())
}

/// Compute the SHA-256 hash of a file.
pub fn compute_sha256<P: AsRef<Path>>(path: P) -> std::io::Result<String> {
    let file = fs::File::open(path)?;
    let mut reader = BufReader::new(file);
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 1024];
    loop {
        let n = reader.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        hasher.update(&buffer[..n]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

/// Processes build artifacts
pub fn process_artifacts(
    out_link: &std::path::Path,
    final_build_dir: &std::path::Path,
    build_id: &str,
    whitelist: &[&str],
) -> Result<Vec<Value>, String> {
    let mut artifacts_info = Vec::new();
    let entries =
        fs::read_dir(out_link).map_err(|e| format!("Failed to read out_link dir: {:?}", e))?;
    for entry in entries {
        let entry = entry.map_err(|e| format!("Failed to get directory entry: {:?}", e))?;
        let path = entry.path();
        if path.is_file() {
            match path.file_name() {
                Some(filename_osstr) => {
                    let filename = filename_osstr.to_string_lossy().to_string();

                    // Filter by whitelist
                    if !whitelist.contains(&filename.as_str()) {
                        println!("Skipping file not in whitelist: {}", filename);
                        continue;
                    }

                    // Resolve symlinks, and copy real files
                    match fs::canonicalize(&path) {
                        Ok(real_path) => {
                            let dest_file = final_build_dir.join(&filename);

                            if let Err(e) = fs::copy(&real_path, &dest_file) {
                                eprintln!(
                                    "Failed to copy {:?} to {:?}: {:?}",
                                    real_path, dest_file, e
                                );
                                continue;
                            }

                            // Compute SHA256
                            match compute_sha256(&dest_file) {
                                Ok(sha) => {
                                    let download_url =
                                        "/builds/".to_string() + build_id + "/" + &filename;
                                    artifacts_info.push(json!({
                                        "file": filename,
                                        "sha256": sha,
                                        "download_url": download_url
                                    }));
                                }
                                Err(e) => {
                                    eprintln!("Failed to compute sha for {:?}: {:?}", dest_file, e);
                                }
                            }
                        }
                        Err(e) => {
                            eprintln!("Failed to canonicalize {:?}: {:?}", path, e);
                        }
                    }
                }
                None => {
                    eprintln!("Could not get file_name for {:?}", path);
                }
            }
        }
    }
    Ok(artifacts_info)
}

/// Logs the error and returns a standardized HTTP error response.
pub fn handle_error<E: std::fmt::Debug>(desc: &str, error: E) -> HttpResponse {
    println!("{}: {:?}", desc, error);
    HttpResponse::InternalServerError().json(json!({
        "status": "error",
        "message": desc
    }))
}
